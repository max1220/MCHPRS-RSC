#!/usr/bin/env luajit
-- Lua RSC script runner(send RSC commands to MCHPRS Minecraft server from Lua).
local socket = require("socket")
local bit = require("bit")



-- connect to MCHPRS RSC port as client
local tcp = socket.tcp()
local addr = assert(table.remove(arg, 1), "First command-line argument needs to be listen address!")
local port = assert(table.remove(arg, 1), "Second command-line argument needs to be listen port!")
assert(tcp:connect("127.0.0.1", 25566), ("Can't connect to: %q with port: %d"):format(tostring(addr), tostring(port)))



-- basic socket read/write functions for integers
local function receive_u8() return tcp:receive(1):byte() end
local function receive_u32()
	local a = tcp:receive(1):byte()
	local b = tcp:receive(1):byte()
	local c = tcp:receive(1):byte()
	local d = tcp:receive(1):byte()
	return bit.bor(bit.bor(bit.bor(a, bit.lshift(b, 8)), bit.lshift(c, 16)), bit.lshift(d, 24))
end
local function send_u8(i) tcp:send(string.char(i)) end
local function send_u32(i)
	local a = bit.band(i, 0xff)
	local b = bit.band(bit.rshift(i, 8), 0xff)
	local c = bit.band(bit.rshift(i,16), 0xff)
	local d = bit.band(bit.rshift(i,24), 0xff)
	tcp:send(string.char(a,b,c,d))
end



-- socket read/write functions for packets
local function send_packet_cmd_xyz(cmd, x,y,z)
	send_u8(cmd)
	send_u32(x)
	send_u32(y)
	send_u32(z)
end
local function send_get_block(x,y,z)
	send_packet_cmd_xyz(0, x,y,z)
end
local function send_set_block(block_id, x,y,z)
	send_packet_cmd_xyz(1, x,y,z)
	send_u32(block_id)
end
local function send_observe_block(x,y,z)
	send_packet_cmd_xyz(2, x,y,z)
end
local function send_update_block(x,y,z)
	send_packet_cmd_xyz(3, x,y,z)
end

local function receive_cmd_xyz_resp(cmd, x, y, z)
	assert(receive_u8()==cmd)
	local resp_x, resp_y, resp_z = receive_u32(), receive_u32(), receive_u32()
	assert((resp_x==x) and (resp_y==y) and (resp_z==z), ("xyz is: %d %d %d"):format(resp_x, resp_y, resp_z))
	return x, y, z
end
local function receive_get_block_resp(x, y, z)
	receive_cmd_xyz_resp(0, x, y, z)
	local block_id = receive_u32()
	return x, y, z, block_id
end
local function receive_observe_block_resp(x, y, z)
	receive_cmd_xyz_resp(1, x, y, z)
	local block_id = receive_u32()
	return x, y, z, block_id
end


-- user-facing API functions
function set_block(block_id, x, y, z)
	send_set_block(block_id, x, y, z)
end
function get_block(x, y, z)
	send_get_block(x, y, z)
	local _,_,_,block_id = receive_get_block_resp(x, y, z)
	return block_id
end
function observe_block(x, y, z)
	send_observe_block(x, y, z)
	local _,_,_,block_id = receive_observe_block_resp(x, y, z)
	return block_id
end
function update_block(x, y, z)
	send_update_block(x, y, z)
end
function freeze() send_u8(4) end
function unfreeze() send_u8(5) end
function step(n) send_u8(6); send_u32(n) end



-- either run a script(if provided), or drop to an interactive debug shell
local script_path = table.remove(arg, 1)
if script_path then
	dofile(script_path)
else
	print("No script provided!")
	print("Running in interactive mode.")
	print()
	print("Functions:")
	print()
	debug.debug()
end
