#!/usr/bin/env luajit
local socket = require("socket")
local bit = require("bit")
local tcp = socket.tcp()
tcp:connect("127.0.0.1", 25566)
local function receive_u8() return tcp:receive(1):byte() end
local function receive_u32()
	local a = tcp:receive(1):byte()
	local b = tcp:receive(1):byte()
	local c = tcp:receive(1):byte()
	local d = tcp:receive(1):byte()
	return a + b*256 + c*256*256 + d*256*256*256
end
local function send_u8(i) tcp:send(string.char(i)) end
local function send_u32(i)
	local a = bit.band(i, 0xff)
	local b = bit.band(bit.lshift(i, 8), 0xff)
	local c = bit.band(bit.lshift(i,16), 0xff)
	local d = bit.band(bit.lshift(i,24), 0xff)
	tcp:send(string.char(a,b,c,d))
end
local function send_set_block(plot_x, plot_z, block_x, block_y, block_z, block_id)
	send_u8(1)
	send_u32(plot_x)
	send_u32(plot_z)
	send_u32(block_x)
	send_u32(block_y)
	send_u32(block_z)
	send_u32(block_id)
end
local function send_get_block(plot_x, plot_z, block_x, block_y, block_z)
	send_u8(0)
	send_u32(plot_x)
	send_u32(plot_z)
	send_u32(block_x)
	send_u32(block_y)
	send_u32(block_z)
end
local function recv_get_block_resp()
	local resp_id = assert(receive_u8()==0)
	local plot_x = receive_u32()
	local plot_z = receive_u32()
	local block_x = receive_u32()
	local block_y = receive_u32()
	local block_z = receive_u32()
	local block_id = receive_u32()
	return resp_id, plot_x, plot_z, block_x, block_y, block_z, block_id	
end
local function get_block(plot_x, plot_z, block_x, block_y, block_z)
	send_get_block(plot_x, plot_z, block_x, block_y, block_z)
	local _,_,_,_,_,_,block_id = recv_get_block_resp()
	return block_id
end



for i=1, 10 do
	send_set_block(0,0, i,i,i, 535)
end
assert(get_block(0,0, 0,0,0, 535))
