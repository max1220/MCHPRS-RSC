local function make_rsc_client(con)
	local client = {}

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
	local function send_packet_cmd(cmd) con:send(string.char(cmd)) end
	local function send_packet_cmd_i(cmd, i) con:send(string.char(cmd)..encode_u32(i)) end
	local function send_packet_cmd_xyz(cmd, x,y,z)
		con:send(encode_u8(cmd)..encode_u32(x)..encode_u32(y)..encode_u32(z))
	end
	local function send_packet_cmd_xyzi(cmd, i, x,y,z)
		con:send(encode_u8(cmd)..encode_u32(x)..encode_u32(y)..encode_u32(z)..encode_u32(i))
	end
	local function send_get_block(x,y,z) send_packet_cmd_xyz(0, x,y,z) end
	local function send_set_block(block_id, x,y,z) send_packet_cmd_xyzi(1, block_id, x,y,z) end
	local function send_observe_block(x,y,z) send_packet_cmd_xyz(2, x,y,z) end
	local function send_update_block(x,y,z) send_packet_cmd_xyz(3, x,y,z) end
	local function receive_cmd_xyzi_resp(cmd, assert_x, assert_y, assert_z)
		local packet = con:receive(17)
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
	local function receive_get_block_resp(x, y, z) return receive_cmd_xyzi_resp(0, x, y, z) end
	local function receive_observe_block_resp(x, y, z) return receive_cmd_xyzi_resp(1, x, y, z) end


	-- user-facing API functions
	function client.set_block(block_id, x, y, z) send_set_block(block_id, x, y, z) end
	function client.get_block(x, y, z)
		send_get_block(x, y, z)
		local _,_,_,block_id = receive_get_block_resp(x, y, z)
		return block_id
	end
	function client.observe_block(x, y, z)
		send_observe_block(x, y, z)
		local _,_,_,block_id = receive_observe_block_resp(x, y, z)
		return block_id
	end
	function client.update_block(x, y, z) send_update_block(x, y, z) end
	function client.freeze() send_packet_cmd(4) end
	function client.unfreeze() send_packet_cmd(5) end
	function client.step(n) send_packet_cmd_i(6, n) end

	return client
end

-- return the module
return {
	make_rsc_client = make_rsc_client
}
