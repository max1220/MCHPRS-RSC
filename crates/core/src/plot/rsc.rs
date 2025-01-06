use super::{Plot};
use bincode::ErrorKind;
use byteorder::{BigEndian, LittleEndian, ReadBytesExt, WriteBytesExt};
use mchprs_blocks::{blocks::Block, BlockPos};
use mchprs_world::World;
use std::{io::{Read, Write}, net::{TcpListener, TcpStream}, sync::mpsc::{self, Receiver, Sender}, thread};
use tracing::{warn, info};

#[derive(Debug, Clone)]
pub enum RSCRequest {
    GetBlock(i32, i32, i32),
    SetBlock(i32, i32, i32, u32),
}
#[derive(Debug, Clone)]
pub enum RSCResponse {
    GetBlockResp(i32, i32, i32, u32),
}

impl Plot {
	pub(super) fn rsc_handle(mut stream: TcpStream, tx: Sender<RSCRequest>, rx: Receiver<RSCResponse>) {
		warn!("RSC thread Handling: {:?}", stream);
		loop {
			// handle requests from the TCP connection for the plot
			let cmd = stream.read_i8();
			match cmd {
				Ok(0) => {
					let block_x = stream.read_i32::<LittleEndian>().unwrap();
					let block_y = stream.read_i32::<LittleEndian>().unwrap();
					let block_z = stream.read_i32::<LittleEndian>().unwrap();
					warn!("RSC thread sending RSCRequest::GetBlock to plot thread ...");
					tx.send(RSCRequest::GetBlock(block_x, block_y, block_z)).unwrap();
					if let Ok(RSCResponse::GetBlockResp(block_x, block_y, block_z, block_id)) = rx.recv() {
						if stream.write_i8(0).is_err() { return; }
						warn!("Got RSCResponse::GetBlockResp: {}", block_id);
						stream.write_i32::<LittleEndian>(block_x).unwrap();
						stream.write_i32::<LittleEndian>(block_y).unwrap();
						stream.write_i32::<LittleEndian>(block_z).unwrap();
						stream.write_u32::<LittleEndian>(block_id).unwrap();
					}
				}
				Ok(1) => {
					let block_x = stream.read_i32::<LittleEndian>().unwrap();
					let block_y = stream.read_i32::<LittleEndian>().unwrap();
					let block_z = stream.read_i32::<LittleEndian>().unwrap();
					let block_id = stream.read_u32::<LittleEndian>().unwrap();
					warn!("RSC thread sending RSCRequest::SetBlock to plot thread ...");
					tx.send(RSCRequest::SetBlock(block_x, block_y, block_z, block_id)).unwrap();
				}
				Ok(cmd_id) => {
					warn!("Got unknown command: {}", cmd_id);
					let _ = stream.shutdown(std::net::Shutdown::Both);
					return;
				}
				Err(e) => {
					warn!("Got error: {}", e);
					let _ = stream.shutdown(std::net::Shutdown::Both);
					return;
				}
			}
		}
	}

	// called by the rsc_listen chat command
	pub(super) fn rsc_listen(&mut self, bind_addr: &str) {
		if self.rsc_listener.is_some() {
			let local_addr = self.rsc_listener.as_mut().unwrap().local_addr().unwrap();
			warn!("Already listening: {:?}", local_addr);
			return;
		}
		let listener = TcpListener::bind(bind_addr).unwrap();
		warn!("RSC Listening on: {}", bind_addr);
		listener.set_nonblocking(true).unwrap();
		self.rsc_listener = Some(listener);
    }

	// called to update the RSC connections
	pub(super) fn rsc_update(&mut self) {
		// only relevant if a listnerer is present
		if self.rsc_listener.is_none() { return; }

		// check if a new connections needs accepting
		if let Ok((client, addr)) = self.rsc_listener.as_mut().unwrap().accept() {
			warn!("Server thread accepting new RSC connection from: {:?}", addr);
			let (rsc_req_tx, rsc_req_rx) = mpsc::channel();
			let (rsc_resp_tx, rsc_resp_rx) = mpsc::channel();
			thread::spawn(move || {
				warn!("RSC handler thread starting ...");
				Self::rsc_handle(client, rsc_req_tx, rsc_resp_rx);
				warn!("RSC handler thread stopped.");
			});
			self.rsc_req_rx = Some(rsc_req_rx);
			self.rsc_resp_tx = Some(rsc_resp_tx);
		}

		// check if there are requests for this plot
		if self.rsc_resp_tx.is_none() || self.rsc_req_rx.is_none() { return; }
		let tx = self.rsc_resp_tx.as_mut().unwrap();
		let rx = self.rsc_req_rx.as_mut().unwrap();
		while let Ok(rsc_req) = rx.try_recv() {
			warn!("Plot handling RSC request: {:?}", rsc_req);
			match rsc_req {
				RSCRequest::GetBlock(block_x, block_y, block_z) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					let block = self.world.get_block(pos);
					warn!("get block {:?} -> {:?}", pos, block);
					tx.send(RSCResponse::GetBlockResp(block_x, block_y, block_z, block.get_id())).unwrap();
				}
				RSCRequest::SetBlock(block_x, block_y, block_z, block_id) => {
					let pos = BlockPos::new(block_x, block_y, block_z);
					warn!("set block {:?} -> {:?}", pos, block_id);
					self.world.set_block(pos, Block::from_id(block_id));
				}
			}
		}
	}
}