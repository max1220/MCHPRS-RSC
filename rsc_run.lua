#!/usr/bin/env luajit
-- Lua RSC script runner(send RSC commands to MCHPRS Minecraft server from Lua).
local socket = require("socket")
local bit = require("bit")



-- connect to MCHPRS RSC port as client
local tcp = socket.tcp()
local addr = assert(table.remove(arg, 1), "First command-line argument needs to be listen address!")
local port = assert(table.remove(arg, 1), "Second command-line argument needs to be listen port!")
assert(tcp:connect("127.0.0.1", 25566), ("Can't connect to: %q with port: %d"):format(tostring(addr), tostring(port)))


-- packing/unpacking functions
local function decode_u8(data, i) return data:byte(i); end
local function decode_u32(data, i)
	local a,b,c,d = assert(data:byte(i,i+3))
	return bit.bor(bit.bor(bit.bor(a, bit.lshift(b, 8)), bit.lshift(c, 16)), bit.lshift(d, 24))
end
local function encode_u8(i) return string.char(i); end
local function encode_u32(i)
	local a = bit.band(i, 0xff)
	local b = bit.band(bit.rshift(i, 8), 0xff)
	local c = bit.band(bit.rshift(i,16), 0xff)
	local d = bit.band(bit.rshift(i,24), 0xff)
	return string.char(a,b,c,d)
end



-- socket read/write functions for RSC packets
local function send_packet_cmd(cmd) tcp:send(string.char(cmd)) end
local function send_packet_cmd_i(cmd, i) tcp:send(string.char(cmd)..encode_u32(i)) end
local function send_packet_cmd_xyz(cmd, x,y,z)
	tcp:send(encode_u8(cmd)..encode_u32(x)..encode_u32(y)..encode_u32(z))
end
local function send_packet_cmd_xyzi(cmd, i, x,y,z)
	tcp:send(encode_u8(cmd)..encode_u32(x)..encode_u32(y)..encode_u32(z)..encode_u32(i))
end
local function send_get_block(x,y,z)
	send_packet_cmd_xyz(0, x,y,z)
end
local function send_set_block(block_id, x,y,z)
	send_packet_cmd_xyzi(1, block_id, x,y,z)
end
local function send_observe_block(x,y,z)
	send_packet_cmd_xyz(2, x,y,z)
end
local function send_update_block(x,y,z)
	send_packet_cmd_xyz(3, x,y,z)
end
local function receive_cmd_xyzi_resp(cmd, assert_x, assert_y, assert_z)
	local packet = tcp:receive(17)
	assert(decode_u8(packet, 1)==cmd)
	local resp_x = decode_u32(packet, 2)
	local resp_y = decode_u32(packet, 6)
	local resp_z = decode_u32(packet, 10)
	local resp_i = decode_u32(packet, 14)
	if assert_x ~= nil then
		assert(
			(resp_x==assert_x) and (resp_y==assert_y) and (resp_z==assert_z),
			("xyz is: %d %d %d, expected: %d %d %d"):format(resp_x, resp_y, resp_z, assert_x, assert_y, assert_z)
		)
	end
	return resp_x, resp_y, resp_z, resp_i
end
local function receive_get_block_resp(x, y, z)
	return receive_cmd_xyzi_resp(0, x, y, z)
end
local function receive_observe_block_resp(x, y, z)
	return receive_cmd_xyzi_resp(1, x, y, z)
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
function freeze() send_packet_cmd(4) end
function unfreeze() send_packet_cmd(5) end
function step(n) send_packet_cmd_i(6, n) end



-- either run a script(if provided), or drop to an interactive debug shell
local script_path = table.remove(arg, 1)
if script_path then
	dofile(script_path)
else
	print([[
No script provided!
Running in interactive mode(Lua REPL).

Available functions:
 * set_block(id, x,y,z)      -- set block
 * id = get_block(x,y,z)     -- read block
 * id = observe_block(x,y,z) -- wait for block change
 * update_block(x,y,z)       -- update (surrounding) blocks after set
 * freeze()                  -- disable redstone ticking
 * unfreeze()                -- enable redstone ticking
 * step(n)                   -- run n redstone ticks
]])
	debug.debug()
end
