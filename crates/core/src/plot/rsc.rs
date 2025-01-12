use super::Plot;
use bus::{Bus, BusReader};
use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use mchprs_blocks::{blocks::Block, BlockPos};
use mchprs_world::World;
use std::{io::{BufReader, BufWriter, Write}, net::{TcpListener, TcpStream}, sync::mpsc::{self, Sender}, thread};
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
}
#[derive(Debug, Clone)]
pub enum RSCResponse {
    GetBlockResp(i32, i32, i32, u32),
	ObserveBlockResp(i32, i32, i32, u32),
}

impl Plot {

	// thread to listen to responses from the main thread and write packets to the stream
	fn rsc_con_responder(stream: TcpStream, mut rx: BusReader<RSCResponse>) {
		debug!("[RSC responder thread] starting with stream: {:?}", stream);
		let mut writer = BufWriter::new(stream);
		loop {
			match rx.recv() {
				Ok(RSCResponse::GetBlockResp(block_x, block_y, block_z, block_id)) => {
					debug!("[RSC responder thread] forwarding GetBlockResp...");
					writer.write_i8(0).unwrap();
					writer.write_i32::<LittleEndian>(block_x).unwrap();
					writer.write_i32::<LittleEndian>(block_y).unwrap();
					writer.write_i32::<LittleEndian>(block_z).unwrap();
					writer.write_u32::<LittleEndian>(block_id).unwrap();
					writer.flush().unwrap();
					debug!("[RSC responder thread] GetBlockResp forward done!");
				},
				Ok(RSCResponse::ObserveBlockResp(block_x, block_y, block_z, block_id)) => {
					debug!("[RSC responder thread] forwarding ObserveBlockResp...");
					writer.write_i8(1).unwrap();
					writer.write_i32::<LittleEndian>(block_x).unwrap();
					writer.write_i32::<LittleEndian>(block_y).unwrap();
					writer.write_i32::<LittleEndian>(block_z).unwrap();
					writer.write_u32::<LittleEndian>(block_id).unwrap();
					writer.flush().unwrap();
					debug!("[RSC responder thread] ObserveBlockResp forward done!");
				},
				Err(e) => {
					panic!("[RSC responder thread] disconnected: {}", e);
				}
			}
		}
	}

	// handler thread for an incoming connection
	fn rsc_con_handle(stream: TcpStream, tx: Sender<RSCRequest>, rx: BusReader<RSCResponse>) {
		debug!("[RSC handle thread] starting with stream: {:?}", stream);

		// create a thread to listen to response from the main thread and write packets to the stream
		let responder_stream = stream.try_clone().unwrap();
		thread::spawn(move || {
			Self::rsc_con_responder(responder_stream, rx)
		});

		// wait for commands, and forward requests to the main thread
		let mut reader = BufReader::new(stream);
		loop {
			let cmd = reader.read_i8().unwrap();
			match cmd {
				0 => {
					// GetBlock command
					debug!("[RSC handle thread] got GetBlock...");
					let block_x = reader.read_i32::<LittleEndian>().unwrap();
					let block_y = reader.read_i32::<LittleEndian>().unwrap();
					let block_z = reader.read_i32::<LittleEndian>().unwrap();
					debug!("[RSC handle thread] got GetBlock RSC command: {} {} {}, sending to plot thread...", block_x, block_y, block_z);
					tx.send(RSCRequest::GetBlock(block_x, block_y, block_z)).unwrap();
					debug!("[RSC handle thread] Request sent!");
				}
				1 => {
					// SetBlock command
					debug!("[RSC handle thread] got SetBlock...");
					let block_x = reader.read_i32::<LittleEndian>().unwrap();
					let block_y = reader.read_i32::<LittleEndian>().unwrap();
					let block_z = reader.read_i32::<LittleEndian>().unwrap();
					let block_id = reader.read_u32::<LittleEndian>().unwrap();
					debug!("RSC handle thread got SetBlock RSC command: {} {} {} -> {}", block_x, block_y, block_z, block_id);
					tx.send(RSCRequest::SetBlock(block_x, block_y, block_z, block_id)).unwrap();
				}
				2 => {
					// ObserveBlock command
					debug!("[RSC handle thread] got ObserveBlock...");
					let block_x = reader.read_i32::<LittleEndian>().unwrap();
					let block_y = reader.read_i32::<LittleEndian>().unwrap();
					let block_z = reader.read_i32::<LittleEndian>().unwrap();
					debug!("RSC handle thread got ObserveBlock RSC command: {} {} {}", block_x, block_y, block_z);
					tx.send(RSCRequest::ObserveBlock(block_x, block_y, block_z)).unwrap();
				}
				3 => {
					// UpdateBlock command
					debug!("[RSC handle thread] got UpdateBlock...");
					let block_x = reader.read_i32::<LittleEndian>().unwrap();
					let block_y = reader.read_i32::<LittleEndian>().unwrap();
					let block_z = reader.read_i32::<LittleEndian>().unwrap();
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
					let steps = reader.read_u32::<LittleEndian>().unwrap();
					debug!("[RSC handle thread] got TickAdvance RSC command: {}", steps);
					tx.send(RSCRequest::TickAdvance(steps)).unwrap();
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
				Self::rsc_con_handle(client, req_tx, resp_rx);
			});
		}
	}

	// check if the RSC connections sent any requests and handle them(called from rsc_update in plot thread)
	fn rsc_plot_handle(&mut self) {
		loop {
			match self.rsc_req_ch.as_mut().unwrap().1.try_recv() {
				Ok(RSCRequest::GetBlock(block_x, block_y, block_z)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received GetBlock request {:?}", pos);
					let block = self.world.get_block(pos);
					self.rsc_resp_bus.as_mut().unwrap().broadcast(RSCResponse::GetBlockResp(block_x, block_y, block_z, block.get_id()));
				},
				Ok(RSCRequest::SetBlock(block_x, block_y, block_z, block_id)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received SetBlock request {:?} -> {:?}", pos, block_id);
					self.world.set_block(pos, Block::from_id(block_id));
					self.send_block_change(pos, block_id);
				},
				Ok(RSCRequest::ObserveBlock(block_x, block_y, block_z)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received ObserveBlock request {:?}", pos);
					self.pause_on_block_pos = Some(pos);
					self.pause_on_block_cur = Some(self.world.get_block(pos));
					self.rsc_waiting_for_pause = true;
				},
				Ok(RSCRequest::UpdateBlock(block_x, block_y, block_z)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					debug!("[RSC plot handle] received UpdateBlock request {:?}", pos);
					mchprs_redstone::update_surrounding_blocks(&mut self.world, pos);
				},
				Ok(RSCRequest::EnableTicking()) => {
					debug!("[RSC plot handle] received EnableTicking request");
					self.disable_ticking = false;
				},
				Ok(RSCRequest::DisableTicking()) => {
					debug!("[RSC plot handle] received DisableTicking request");
					self.disable_ticking = true;
				},
				Ok(RSCRequest::TickAdvance(ticks)) => {
					debug!("[RSC plot handle] TickAdvance request");
					for _ in 0..ticks {
						self.tick();
					}
					if self.redpiler.is_active() {
						self.redpiler.flush(&mut self.world);
					}
				},
				Err(_) => { break; }
			}
		}
	}

	// rsc_listen chat command implementation
	// TODO: Send chat responses instead of console messages
	pub(super) fn rsc_listen(&mut self, bind_addr: &str) {
		// check if already listening
		if self.rsc_listener.is_some() {
			let local_addr = self.rsc_listener.as_mut().unwrap().local_addr().unwrap();
			warn!("RSC command failed. Already listening on: {:?}", local_addr);
			return;
		}

		// create TCPListener to accept incoming connections
		let listener = TcpListener::bind(bind_addr).unwrap();
		listener.set_nonblocking(true).unwrap();
		self.rsc_listener = Some(listener);

		// add bus to send RSCResponses from the plot thread to the handler threads
		self.rsc_resp_bus = Some(Bus::new(128));
		// add channel to send RSCRequests from the handler threads to the plot thread
		self.rsc_req_ch = Some(mpsc::channel());

		info!("RSC command ok, listening on: {}", bind_addr);
    }

	// called to update the RSC connections in the plot thread
	pub(super) fn rsc_update(&mut self) {
		// only relevant if a listener is present
		if self.rsc_listener.is_none() { return; }

		// check if a new connections needs accepting
		self.rsc_accept();

		// check if the RSC connections sent any requests
		self.rsc_plot_handle();
	}
}