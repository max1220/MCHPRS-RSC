use super::Plot;
use bus::{Bus, BusReader};
use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use mchprs_blocks::{blocks::Block, BlockPos};
use mchprs_world::World;
use std::{io::{Error, ErrorKind}, net::{TcpListener, TcpStream}, sync::mpsc::{self, Sender}, thread};
use tracing::warn;

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

// wait for the specified(x,y,z) get_block response
fn wait_for_get_block_resp(rx: &mut BusReader<RSCResponse>, block_x: i32, block_y: i32, block_z: i32) -> u32 {
	loop {
		let resp = rx.recv().unwrap();
		match resp {
			RSCResponse::GetBlockResp(resp_block_x, resp_block_y, resp_block_z, resp_block_id) => {
				if (block_x == resp_block_x) && (block_y == resp_block_y) && (block_z == resp_block_z) {
					return resp_block_id;
				}
			},
			_ => {},
		}
	}
}

fn wait_for_observe_block_resp(rx: &mut BusReader<RSCResponse>, block_x: i32, block_y: i32, block_z: i32) -> u32 {
	loop {
		let resp = rx.recv().unwrap();
		match resp {
			RSCResponse::ObserveBlockResp(resp_block_x, resp_block_y, resp_block_z, resp_block_id) => {
				if (block_x == resp_block_x) && (block_y == resp_block_y) && (block_z == resp_block_z) {
					return resp_block_id;
				}
			},
			_ => {},
		}
	}
}


impl Plot {
	// handler thread for an incoming connection
	pub(super) fn rsc_handle(mut stream: TcpStream, tx: Sender<RSCRequest>, mut rx: BusReader<RSCResponse>) -> Result<(), Error> {
		warn!("RSC handle thread starting with stream: {:?}", stream);
		loop {
			// handle requests from the TCP connection for the plot
			warn!("RSC handle thread waiting for RSC command...: {:?}", stream);
			match stream.read_i8() {
				Ok(0) => {
					// GetBlock command
					let block_x = stream.read_i32::<LittleEndian>()?;
					let block_y = stream.read_i32::<LittleEndian>()?;
					let block_z = stream.read_i32::<LittleEndian>()?;
					warn!("RSC handle thread got GetBlock command: {} {} {}", block_x, block_y, block_z);
					tx.send(RSCRequest::GetBlock(block_x, block_y, block_z)).unwrap();
					warn!("RSC handle thread waiting for GetBlock response...");
					let block_id = wait_for_get_block_resp(&mut rx, block_x, block_y, block_z);
					stream.write_i8(0)?;
					stream.write_i32::<LittleEndian>(block_x)?;
					stream.write_i32::<LittleEndian>(block_y)?;
					stream.write_i32::<LittleEndian>(block_z)?;
					stream.write_u32::<LittleEndian>(block_id)?;
				}
				Ok(1) => {
					// SetBlock command
					let block_x = stream.read_i32::<LittleEndian>().unwrap();
					let block_y = stream.read_i32::<LittleEndian>().unwrap();
					let block_z = stream.read_i32::<LittleEndian>().unwrap();
					let block_id = stream.read_u32::<LittleEndian>().unwrap();
					warn!("RSC handle thread got SetBlock command: {} {} {} -> {}", block_x, block_y, block_z, block_id);
					tx.send(RSCRequest::SetBlock(block_x, block_y, block_z, block_id)).unwrap();
				}
				Ok(2) => {
					// ObserveBlock command
					let block_x = stream.read_i32::<LittleEndian>()?;
					let block_y = stream.read_i32::<LittleEndian>()?;
					let block_z = stream.read_i32::<LittleEndian>()?;
					warn!("RSC handle thread got ObserveBlock command: {} {} {}", block_x, block_y, block_z);
					tx.send(RSCRequest::ObserveBlock(block_x, block_y, block_z)).unwrap();
					warn!("RSC handle thread waiting for ObserveBlock response...");
					let block_id = wait_for_observe_block_resp(&mut rx, block_x, block_y, block_z);
					stream.write_i8(1)?;
					stream.write_i32::<LittleEndian>(block_x)?;
					stream.write_i32::<LittleEndian>(block_y)?;
					stream.write_i32::<LittleEndian>(block_z)?;
					stream.write_u32::<LittleEndian>(block_id)?;
				}
				Ok(3) => {
					// UpdateBlock command
					let block_x = stream.read_i32::<LittleEndian>().unwrap();
					let block_y = stream.read_i32::<LittleEndian>().unwrap();
					let block_z = stream.read_i32::<LittleEndian>().unwrap();
					warn!("RSC handle thread got UpdateBlock command: {} {} {}", block_x, block_y, block_z);
					tx.send(RSCRequest::UpdateBlock(block_x, block_y, block_z)).unwrap();
				}
				Ok(4) => {
					// tick freeze command
					tx.send(RSCRequest::DisableTicking()).unwrap();
				}
				Ok(5) => {
					// tick unfreeze command
					tx.send(RSCRequest::EnableTicking()).unwrap();
				}
				Ok(6) => {
					// tick step(radvance) command
					let steps = stream.read_u32::<LittleEndian>().unwrap();
					tx.send(RSCRequest::TickAdvance(steps)).unwrap();
				}
				Ok(cmd_id) => {
					// unknown command
					warn!("RSC handle thread got unknown command: {}", cmd_id);
					stream.shutdown(std::net::Shutdown::Both)?;
					return Err(Error::new(ErrorKind::Other, "Invalid RSC command"));
				},
				Err(e) => {
					// read error
					stream.shutdown(std::net::Shutdown::Both)?;
					return Err(e);
				}
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

		warn!("RSC command ok, listening on: {}", bind_addr);
    }

	// called to update the RSC connections
	pub(super) fn rsc_update(&mut self) {
		// only relevant if a listener is present
		if self.rsc_listener.is_none() { return; }

		// check if a new connections needs accepting
		while let Ok((client, addr)) = self.rsc_listener.as_mut().unwrap().accept() {
			warn!("plot thread RSC update accepting new connection from: {:?}", addr);
			let resp_rx = self.rsc_resp_bus.as_mut().unwrap().add_rx();
			let req_tx = self.rsc_req_ch.as_mut().unwrap().0.clone();
			thread::spawn(move || {
				let _ = Self::rsc_handle(client, req_tx, resp_rx);
				warn!("RSC handle thread died.");
			});
		}

		// check if the RSC connections sent any requests
		loop {
			match self.rsc_req_ch.as_mut().unwrap().1.try_recv() {
				Ok(RSCRequest::GetBlock(block_x, block_y, block_z)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					warn!("plot thread RSC update received GetBlock request {:?}", pos);
					let block = self.world.get_block(pos);
					self.rsc_resp_bus.as_mut().unwrap().broadcast(RSCResponse::GetBlockResp(block_x, block_y, block_z, block.get_id()));
				},
				Ok(RSCRequest::SetBlock(block_x, block_y, block_z, block_id)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					warn!("plot thread RSC update received SetBlock request {:?} -> {:?}", pos, block_id);
					self.world.set_block(pos, Block::from_id(block_id));
					self.send_block_change(pos, block_id);
				},
				Ok(RSCRequest::ObserveBlock(block_x, block_y, block_z)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					warn!("plot thread RSC update received ObserveBlock request {:?}", pos);
					self.pause_on_block_pos = Some(pos);
					self.pause_on_block_cur = Some(self.world.get_block(pos));
					self.rsc_waiting_for_pause = true;
				},
				Ok(RSCRequest::UpdateBlock(block_x, block_y, block_z)) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					warn!("plot thread RSC update received UpdateBlock request {:?}", pos);
					mchprs_redstone::update_surrounding_blocks(&mut self.world, pos);
				},
				Ok(RSCRequest::EnableTicking()) => {
					warn!("plot thread RSC update received EnableTicking request");
					self.disable_ticking = false;
				},
				Ok(RSCRequest::DisableTicking()) => {
					warn!("plot thread RSC update received DisableTicking request");
					self.disable_ticking = true;
				},
				Ok(RSCRequest::TickAdvance(ticks)) => {
					warn!("plot thread RSC update received TickAdvance request");
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
}