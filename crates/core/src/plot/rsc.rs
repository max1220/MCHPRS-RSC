use super::Plot;
use bus::{Bus, BusReader};
use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use mchprs_blocks::{blocks::Block, BlockPos};
use mchprs_world::World;
use std::{io::{BufRead, BufReader, BufWriter, Error, Write}, net::{TcpListener, TcpStream}, sync::mpsc::{self, Sender}, thread::{self}};
use std::time::Duration;
use std::cmp;
use tracing::{debug, info, warn};

#[derive(Debug, Clone)]
pub enum RSCRequest {
    GetBlock(i32, i32, i32),
    SetBlock(i32, i32, i32, u32),
	ObserveBlock(i32, i32, i32),
	UpdateBlock(i32, i32, i32),
	DisableTicking(),
	EnableTicking(),
	TickAdvance(u32),
	GetBlockRange(i32, i32, i32, i32, i32, i32),
	SetBlockRange(i32, i32, i32, i32, i32, i32, Vec<u32>),
	UpdateBlockRange(i32, i32, i32, i32, i32, i32),
	SendChatMessage(Vec<u8>),
}
#[derive(Debug, Clone)]
pub enum RSCResponse {
    GetBlockResp(i32, i32, i32, u32),
	ObserveBlockResp(i32, i32, i32, u32),
	GetBlockRangeResp(i32, i32, i32, i32, i32, i32, Vec<u32>),
	ChatMessageResp(String),
}

impl Plot {

	// thread to listen to responses from the main thread and write packets to the stream
	fn rsc_con_responder(stream: TcpStream, mut rx: BusReader<RSCResponse>) -> Result<(), Error> {
		debug!("[RSC responder thread] starting with stream: {:?}", stream);
		let mut writer = BufWriter::new(stream);
		loop {
			match rx.recv() {
				Ok(RSCResponse::GetBlockResp(block_x, block_y, block_z, block_id)) => {
					debug!("[RSC responder thread] forwarding GetBlockResp...");
					writer.write_i8(0)?;
					writer.write_i32::<LittleEndian>(block_x)?;
					writer.write_i32::<LittleEndian>(block_y)?;
					writer.write_i32::<LittleEndian>(block_z)?;
					writer.write_u32::<LittleEndian>(block_id)?;
					writer.flush()?;
					debug!("[RSC responder thread] GetBlockResp forward done!");
				},
				Ok(RSCResponse::ObserveBlockResp(block_x, block_y, block_z, block_id)) => {
					debug!("[RSC responder thread] forwarding ObserveBlockResp...");
					writer.write_i8(1)?;
					writer.write_i32::<LittleEndian>(block_x)?;
					writer.write_i32::<LittleEndian>(block_y)?;
					writer.write_i32::<LittleEndian>(block_z)?;
					writer.write_u32::<LittleEndian>(block_id)?;
					writer.flush()?;
					debug!("[RSC responder thread] ObserveBlockResp forward done!");
				},
				Ok(RSCResponse::GetBlockRangeResp(min_x, min_y, min_z, max_x, max_y, max_z, blocks)) => {
					debug!("[RSC responder thread] forwarding GetBlockRangeResp...");
					writer.write_i8(2)?;
					writer.write_i32::<LittleEndian>(min_x)?;
					writer.write_i32::<LittleEndian>(min_y)?;
					writer.write_i32::<LittleEndian>(min_z)?;
					writer.write_i32::<LittleEndian>(max_x)?;
					writer.write_i32::<LittleEndian>(max_y)?;
					writer.write_i32::<LittleEndian>(max_z)?;
					let mut i = 0;
					for _ in min_z..max_z {
						for _ in min_y..max_y {
							for _ in min_x..max_x {
								let block_id = blocks[i];
								writer.write_u32::<LittleEndian>(block_id)?;
								i += 1;
							}
						}
					}
					writer.flush()?;
					debug!("[RSC responder thread] GetBlockRangeResp forward done!");
				},
				Ok(RSCResponse::ChatMessageResp(str)) => {
					debug!("[RSC responder thread] forwarding ChatMessageResp...");
					writer.write_i8(3)?;
					for byte in str.as_bytes().iter() {
						writer.write_u8(*byte)?;
					}
					writer.write_i8(0)?;
					writer.flush()?;
					debug!("[RSC responder thread] ChatMessageResp forward done!");
				},
				Err(e) => {
					return Err(Error::other(e));
				}
			}
		}
	}

	// handler thread for an incoming connection
	fn rsc_con_handle(stream: TcpStream, tx: Sender<RSCRequest>, rx: BusReader<RSCResponse>) -> Result<(), Error> {
		debug!("[RSC handle thread] starting with stream: {:?}", stream);

		// create a thread to listen to response from the main thread and write packets to the stream
		let responder_stream = stream.try_clone()?;
		thread::spawn(move || {
			if let Err(err) = Self::rsc_con_responder(responder_stream, rx) {
				// TODO: Currently there is no clean way of shutting down a single responder thread, so just let it die in silence
				debug!("RSC responder thread died! Reason: {}", err);
			}
		});

		// wait for commands, and forward requests to the main thread
		let mut reader = BufReader::new(stream.try_clone()?);
		loop {
			let cmd = reader.read_i8()?;
			match cmd {
				0 => {
					// GetBlock command
					debug!("[RSC handle thread] got GetBlock...");
					let block_x = reader.read_i32::<LittleEndian>()?;
					let block_y = reader.read_i32::<LittleEndian>()?;
					let block_z = reader.read_i32::<LittleEndian>()?;
					debug!("[RSC handle thread] got GetBlock RSC command: {} {} {}, sending to plot thread...", block_x, block_y, block_z);
					tx.send(RSCRequest::GetBlock(block_x, block_y, block_z)).unwrap();
					debug!("[RSC handle thread] Request sent!");
				}
				1 => {
					// SetBlock command
					debug!("[RSC handle thread] got SetBlock...");
					let block_x = reader.read_i32::<LittleEndian>()?;
					let block_y = reader.read_i32::<LittleEndian>()?;
					let block_z = reader.read_i32::<LittleEndian>()?;
					let block_id = reader.read_u32::<LittleEndian>()?;
					debug!("RSC handle thread got SetBlock RSC command: {} {} {} -> {}", block_x, block_y, block_z, block_id);
					tx.send(RSCRequest::SetBlock(block_x, block_y, block_z, block_id)).unwrap();
				}
				2 => {
					// ObserveBlock command
					debug!("[RSC handle thread] got ObserveBlock...");
					let block_x = reader.read_i32::<LittleEndian>()?;
					let block_y = reader.read_i32::<LittleEndian>()?;
					let block_z = reader.read_i32::<LittleEndian>()?;
					debug!("RSC handle thread got ObserveBlock RSC command: {} {} {}", block_x, block_y, block_z);
					tx.send(RSCRequest::ObserveBlock(block_x, block_y, block_z)).unwrap();
				}
				3 => {
					// UpdateBlock command
					debug!("[RSC handle thread] got UpdateBlock...");
					let block_x = reader.read_i32::<LittleEndian>()?;
					let block_y = reader.read_i32::<LittleEndian>()?;
					let block_z = reader.read_i32::<LittleEndian>()?;
					debug!("RSC handle thread got UpdateBlock RSC command: {} {} {}", block_x, block_y, block_z);
					tx.send(RSCRequest::UpdateBlock(block_x, block_y, block_z)).unwrap();
				}
				4 => {
					// tick freeze command
					debug!("[RSC handle thread] got DisableTicking RSC command");
					tx.send(RSCRequest::DisableTicking()).unwrap();
				}
				5 => {
					// tick unfreeze command
					debug!("[RSC handle thread] got EnableTicking RSC command");
					tx.send(RSCRequest::EnableTicking()).unwrap();
				}
				6 => {
					// tick step(radvance) command
					let steps = reader.read_u32::<LittleEndian>()?;
					debug!("[RSC handle thread] got TickAdvance RSC command: {}", steps);
					tx.send(RSCRequest::TickAdvance(steps)).unwrap();
				}
				7 => {
					// get block range
					debug!("[RSC handle thread] got GetBlockRange RSC command");
					let mut min_x = reader.read_i32::<LittleEndian>()?;
					let mut min_y = reader.read_i32::<LittleEndian>()?;
					let mut min_z = reader.read_i32::<LittleEndian>()?;
					let mut max_x = reader.read_i32::<LittleEndian>()?;
					let mut max_y = reader.read_i32::<LittleEndian>()?;
					let mut max_z = reader.read_i32::<LittleEndian>()?;
					(min_x, max_x) = (cmp::min(min_x, max_x), std::cmp::max(min_x, max_x));
					(min_y, max_y) = (cmp::min(min_y, max_y), std::cmp::max(min_y, max_y));
					(min_z, max_z) = (cmp::min(min_z, max_z), std::cmp::max(min_z, max_z));
					tx.send(RSCRequest::GetBlockRange(min_x, min_y, min_z, max_x, max_y, max_z)).unwrap();
				}
				8 => {
					// set block range
					debug!("[RSC handle thread] got SetBlockRange RSC command");
					let mut min_x = reader.read_i32::<LittleEndian>()?;
					let mut min_y = reader.read_i32::<LittleEndian>()?;
					let mut min_z = reader.read_i32::<LittleEndian>()?;
					let mut max_x = reader.read_i32::<LittleEndian>()?;
					let mut max_y = reader.read_i32::<LittleEndian>()?;
					let mut max_z = reader.read_i32::<LittleEndian>()?;
					(min_x, max_x) = (cmp::min(min_x, max_x), std::cmp::max(min_x, max_x));
					(min_y, max_y) = (cmp::min(min_y, max_y), std::cmp::max(min_y, max_y));
					(min_z, max_z) = (cmp::min(min_z, max_z), std::cmp::max(min_z, max_z));
					let mut blocks = vec![];
					for _ in min_z..max_z {
						for _ in min_y..max_y {
							for _ in min_x..max_x {
								blocks.push(reader.read_u32::<LittleEndian>()?);
							}
						}
					}
					tx.send(RSCRequest::SetBlockRange(min_x, min_y, min_z, max_x, max_y, max_z, blocks)).unwrap();
				}
				9 => {
					// update block range
					debug!("[RSC handle thread] got UpdateBlockRange RSC command");
					let mut min_x = reader.read_i32::<LittleEndian>()?;
					let mut min_y = reader.read_i32::<LittleEndian>()?;
					let mut min_z = reader.read_i32::<LittleEndian>()?;
					let mut max_x = reader.read_i32::<LittleEndian>()?;
					let mut max_y = reader.read_i32::<LittleEndian>()?;
					let mut max_z = reader.read_i32::<LittleEndian>()?;
					(min_x, max_x) = (cmp::min(min_x, max_x), std::cmp::max(min_x, max_x));
					(min_y, max_y) = (cmp::min(min_y, max_y), std::cmp::max(min_y, max_y));
					(min_z, max_z) = (cmp::min(min_z, max_z), std::cmp::max(min_z, max_z));
					tx.send(RSCRequest::UpdateBlockRange(min_x, min_y, min_z, max_x, max_y, max_z)).unwrap();
				},
				10 => {
					debug!("[RSC handle thread] got SendChatMessage RSC command");
					let mut msg = vec![];
					reader.read_until(0, &mut msg)?;
					tx.send(RSCRequest::SendChatMessage(msg)).unwrap();
				},
				11 => {
					debug!("[RSC handle thread] got Exit RSC command");
					stream.shutdown(std::net::Shutdown::Both)?;
					return Ok(());
				}
				cmd_id => {
					// unknown command
					panic!("[RSC handle thread] Invalid RSC command ID: {}", cmd_id);
				}
			}
		}
	}

	// check if a new connections needs accepting
	fn rsc_accept(&mut self) {
		while let Ok((client, addr)) = self.rsc_listener.as_ref().unwrap().accept() {
			info!("[RSC accept thread] new connection from: {:?}", addr);
			let resp_rx = self.rsc_resp_bus.as_mut().unwrap().add_rx();
			let req_tx = self.rsc_req_ch.as_ref().unwrap().0.clone();
			thread::spawn(move || {
				let addr = client.peer_addr().unwrap();
				if let Err(err) = Self::rsc_con_handle(client, req_tx, resp_rx) {
					warn!("RSC handler thread for {} died! Reason: {}", addr, err);
				} else {
					info!("Graceful shutdown of RSC connection: {}", addr);
				}
			});
		}
	}

	// check if the RSC connections sent any requests and handle them(called from rsc_update in plot thread)
	fn rsc_plot_handle(&mut self, timeout: Option<Duration>) {
		loop {
			let req: RSCRequest;
			if timeout.is_some() {
				let res = self.rsc_req_ch.as_mut().unwrap().1.recv_timeout(timeout.unwrap());
				if res.is_ok() { req = res.unwrap(); }
				else { break; }
			} else {
				let res = self.rsc_req_ch.as_mut().unwrap().1.try_recv();
				if res.is_ok() { req = res.unwrap(); }
				else { break; }
			}
			match req {
				RSCRequest::GetBlock(block_x, block_y, block_z) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received GetBlock request {:?}", pos);
					let block = self.world.get_block(pos);
					self.rsc_resp_bus.as_mut().unwrap().broadcast(RSCResponse::GetBlockResp(block_x, block_y, block_z, block.get_id()));
				},
				RSCRequest::SetBlock(block_x, block_y, block_z, block_id) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received SetBlock request {:?} -> {:?}", pos, block_id);
					self.world.set_block(pos, Block::from_id(block_id));
					self.send_block_change(pos, block_id);
				},
				RSCRequest::ObserveBlock(block_x, block_y, block_z) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received ObserveBlock request {:?}", pos);
					self.pause_observers.push((pos, self.world.get_block(pos), true));
				},
				RSCRequest::UpdateBlock(block_x, block_y, block_z) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received UpdateBlock request {:?}", pos);
					mchprs_redstone::update_surrounding_blocks(&mut self.world, pos);
				},
				RSCRequest::EnableTicking() => {
					debug!("[RSC plot handle] received EnableTicking request");
					self.disable_ticking = false;
				},
				RSCRequest::DisableTicking() => {
					debug!("[RSC plot handle] received DisableTicking request");
					self.disable_ticking = true;
				},
				RSCRequest::TickAdvance(ticks) => {
					debug!("[RSC plot handle] TickAdvance request");
					for _ in 0..ticks {
						self.tick();
					}
					if self.redpiler.is_active() {
						self.redpiler.flush(&mut self.world);
					}
				},
				RSCRequest::GetBlockRange(min_x, min_y, min_z, max_x, max_y, max_z) => {
					debug!("[RSC plot handle] received GetBlockRange request");
					let mut blocks:Vec<u32> = vec![];
					for z in min_z..max_z {
						for y in min_y..max_y {
							for x in min_x..max_x {
								let block = self.world.get_block(BlockPos::new(x, y, z));
								blocks.push(block.get_id());
							}
						}
					}
					self.rsc_resp_bus.as_mut().unwrap().broadcast(RSCResponse::GetBlockRangeResp(min_x, min_y, min_z, max_x, max_y, max_z, blocks));
				},
				RSCRequest::SetBlockRange(min_x, min_y, min_z, max_x, max_y, max_z, blocks) => {
					debug!("[RSC plot handle] received SetBlockRange request");
					let mut i = 0;
					for z in min_z..max_z {
						for y in min_y..max_y {
							for x in min_x..max_x {
								let block = Block::from_id(blocks[i]);
								self.world.set_block(BlockPos::new(x, y, z), block);
								i += 1;
							}
						}
					}
				},
				RSCRequest::UpdateBlockRange(min_x, min_y, min_z, max_x, max_y, max_z) => {
					debug!("[RSC plot handle] received UpdateBlockRange request");
					for z in min_z..max_z {
						for y in min_y..max_y {
							for x in min_x..max_x {
								mchprs_redstone::update_surrounding_blocks(&mut self.world, BlockPos::new(x, y, z));
							}
						}
					}
				},
				RSCRequest::SendChatMessage(mut msg) => {
					debug!("[RSC plot handle] received SendChatMessage request");
					msg.pop();
					self.broadcast_plot_chat_message(std::str::from_utf8(&msg).unwrap());
				}
			}
		}
	}

	// check if any of the pause conditions are met after each tick
	pub(super) fn rsc_pause_observer_handle(&mut self) {
		for i in 0..self.pause_observers.len() {
			let (pos, block, is_rsc) = self.pause_observers[i];
			let cur_block = self.world.get_block(pos);
			if cur_block != block {
				debug!("Game paused by block change at {}: {:?} -> {:?}", pos, block, cur_block);
				self.pause_observers.pop();
				self.disable_ticking = true;
				if is_rsc {
					debug!("Paused by RSC, notifying responder threads...");
					let bus = self.rsc_resp_bus.as_mut().unwrap();
					bus.broadcast(RSCResponse::ObserveBlockResp(pos.x, pos.y, pos.z, cur_block.get_id()));
				} else {
					self.broadcast_plot_chat_message(&format!("Game paused by block change at {}: {:?} -> {:?}", pos, block, cur_block));
				}
				// we have paused the game, no need to check more pause conditions
				return;
			}
		}
	}

	// rsc_listen chat command implementation
	// TODO: Send chat responses instead of console messages
	pub(super) fn rsc_listen(&mut self, bind_addr: &str) -> Result<(), Error> {
		// check if already listening
		if self.rsc_listener.is_some() {
			let local_addr = self.rsc_listener.as_mut().unwrap().local_addr().unwrap();
			warn!("Already listening on: {:?}", local_addr);
			return Err(Error::other(format!("Already listening on: {:?}", local_addr)));
		}

		info!("Listening on: {:?}", bind_addr);

		// create TCPListener to accept incoming connections
		let listener = TcpListener::bind(bind_addr).unwrap();
		listener.set_nonblocking(true)?;
		self.rsc_listener = Some(listener);

		// add bus to send RSCResponses from the plot thread to the handler threads
		self.rsc_resp_bus = Some(Bus::new(128));
		// add channel to send RSCRequests from the handler threads to the plot thread
		self.rsc_req_ch = Some(mpsc::channel());

		return Ok(())
    }

	// called to update the RSC connections in the plot thread
	pub(super) fn rsc_update(&mut self, timeout: Option<Duration>) {
		if self.rsc_listener.is_none() {
			// if no listener is present only sleep if a timeout was requested
			if timeout.is_some() { thread::sleep(timeout.unwrap()); }
			return;
		}

		// check if a new connections needs accepting
		self.rsc_accept();

		// check if the RSC connections sent any requests
		self.rsc_plot_handle(timeout);
	}
}