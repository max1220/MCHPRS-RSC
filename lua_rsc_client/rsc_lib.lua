local function make_rsc_client(con)

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



	-- socket send functions for RSC packets
	local function send_packet_cmd(cmd) con:send(string.char(cmd)) end
	local function send_packet_cmd_i(cmd, i) con:send(string.char(cmd)..encode_u32(i)) end
	local function send_packet_cmd_xyz(cmd, x,y,z)
		con:send(encode_u8(cmd)..encode_u32(x)..encode_u32(y)..encode_u32(z))
	end
	local function send_packet_cmd_xyzi(cmd, i, x,y,z)
		con:send(encode_u8(cmd)..encode_u32(x)..encode_u32(y)..encode_u32(z)..encode_u32(i))
	end
	local function send_packet_cmd_xyzxyz(cmd, x0,y0,z0, x1,y1,z1)
		con:send(encode_u8(cmd)..encode_u32(x0)..encode_u32(y0)..encode_u32(z0)..encode_u32(x1)..encode_u32(y1)..encode_u32(z1))
	end
	local function send_get_block(x,y,z) send_packet_cmd_xyz(0, x,y,z) end
	local function send_set_block(block_id, x,y,z) send_packet_cmd_xyzi(1, block_id, x,y,z) end
	local function send_observe_block(x,y,z) send_packet_cmd_xyz(2, x,y,z) end
	local function send_update_block(x,y,z) send_packet_cmd_xyz(3, x,y,z) end
	local function send_freeze() send_packet_cmd(4) end
	local function send_unfreeze() send_packet_cmd(5) end
	local function send_step(n) send_packet_cmd_i(6, n) end
	local function send_get_block_range(x_min,y_min,z_min, x_max,y_max,z_max)
		send_packet_cmd_xyzxyz(7, x_min,y_min,z_min, x_max,y_max,z_max)
	end
	local function send_set_block_range(x_min,y_min,z_min, x_max,y_max,z_max, blocks)
		local w = x_max-x_min
		local h = y_max-y_min
		local d = z_max-z_min
		assert((w>0) and (h>0) and (d>0))
		assert(#blocks == w*h*d, ("Expected %d blocks, got %d"):format(w*h*d, #blocks))
		local packet_header = encode_u8(8)..encode_u32(x_min)..encode_u32(y_min)..encode_u32(z_min)..encode_u32(x_max)..encode_u32(y_max)..encode_u32(z_max)
		local packet_body = {}
		for _, block in ipairs(blocks) do
			table.insert(packet_body, encode_u32(block))
		end
		con:send(packet_header .. table.concat(packet_body,""))
	end
	local function send_update_block_range(x_min,y_min,z_min, x_max,y_max,z_max)
		send_packet_cmd_xyzxyz(7, x_min,y_min,z_min, x_max,y_max,z_max)
	end
	local function send_chat_message(str)
		con:send(string.char(10)..str.."\000")
	end

	-- socket receive functions for RSC packets
	local function receive_xyzi_resp()
		local packet = con:receive(16)
		local resp_x = decode_u32(packet, 1)
		local resp_y = decode_u32(packet, 5)
		local resp_z = decode_u32(packet, 9)
		local resp_i = decode_u32(packet, 13)
		return resp_x, resp_y, resp_z, resp_i
	end
	local function receive_get_block_range_resp()
		local packet_header = con:receive(24)
		local x_min = decode_u32(packet_header, 1)
		local y_min = decode_u32(packet_header, 5)
		local z_min = decode_u32(packet_header, 9)
		local x_max = decode_u32(packet_header, 13)
		local y_max = decode_u32(packet_header, 17)
		local z_max = decode_u32(packet_header, 21)
		local blocks_len = (x_max-x_min) * (y_max-y_min) * (z_max-z_min) * 4
		local packet_body = con:receive(blocks_len)

		local blocks = {}
		for i=1, blocks_len, 4 do
			table.insert(blocks, decode_u32(packet_body, i))
		end
		return x_min,y_min,z_min, x_max,y_max,z_max, blocks
	end
	local function receive_chat_message()
		local chat_msg = {}
		while true do
			local b = con:receive(1)
			if b == "\000" then break end
			table.insert(chat_msg, b)
		end
		return table.concat(chat_msg)
	end



	-- user-facing API functions
	local client = {}
	client.con = con

	-- receive the next packet and decode it
	function client.receive_response()
		local cmd = (con:receive(1) or ""):byte()
		if cmd == 0 then
			return "GetBlockResp", receive_xyzi_resp()
		elseif cmd == 1 then
			return "ObserveBlockResp", receive_xyzi_resp()
		elseif cmd == 2 then
			return "GetBlockRangeResp", receive_get_block_range_resp()
		elseif cmd == 3 then
			return "ChatMessageResp", receive_chat_message()
		elseif cmd ~= nil then
			error("Unknown response!") -- can't recover because response could be any size
		end
	end
	-- wait for a specific response packet
	-- Arguments must match return value of receive_response.
	-- Use "any" to ignore a particular return value.
	function client.wait_for_response(...)
		while true do
			local resp_match = {...}
			local resp = {client.receive_response()}
			if not resp[1] then return; end
			local match = true
			for i=1, math.max(#resp_match, #resp) do
				if (resp_match[i] ~= "any") and (resp_match[i] ~= resp[i]) then

					match = false
					break
				end
			end
			if match then return unpack(resp) end
		end
	end
	-- write a block(if this is a redstone block, call update_block afterwards!)
	function client.set_block(block_id, x, y, z) send_set_block(block_id, x, y, z) end
	-- read a block(returns block ID)
	function client.get_block(x, y, z)
		send_get_block(x, y, z)
		local _,_,_,_,block_id = client.wait_for_response("GetBlockResp", x, y, z, "any")
		return block_id
	end
	-- wait for a block change. Game is frozen afterwards(returns new block ID)
	function client.observe_block(x, y, z)
		send_observe_block(x, y, z)
		local _,_,_,_,block_id = client.wait_for_response("ObserveBlockResp", x, y, z, "any")
		return block_id
	end
	-- update redstone after modifying blocks
	function client.update_block(x, y, z) send_update_block(x, y, z) end
	-- tick-freeze game
	function client.freeze() send_freeze() end
	-- unfreeze game
	function client.unfreeze() send_unfreeze() end
	-- perform n manual redstone steps
	function client.step(n) send_step(n) end
	-- read a volume of blocks(return flat table of block IDs)
	function client.get_block_range(x_min,y_min,z_min, x_max,y_max,z_max)
		send_get_block_range(x_min,y_min,z_min, x_max,y_max,z_max)
		local _,_,_,_,_,_,_,blocks = client.wait_for_response("GetBlockRangeResp", x_min,y_min,z_min, x_max,y_max,z_max, "any")
		return blocks
	end
	-- set a volume of blocks(blocks is a table of block IDs)
	function client.set_block_range(x_min,y_min,z_min, x_max,y_max,z_max, blocks)
		send_set_block_range(x_min,y_min,z_min, x_max,y_max,z_max, blocks)
	end
	-- update_block a volume of blocks after redstone modifications
	function client.update_block_range(x_min,y_min,z_min, x_max,y_max,z_max)
		send_update_block_range(x_min,y_min,z_min, x_max,y_max,z_max)
	end
	-- send a chat message to all players on the plot
	function client.send_chat_message(msg) send_chat_message(msg) end
	-- gracefully shutdown the connection
	function client.disconnect() send_packet_cmd(11) end

	return client
end

-- return the module
return {
	make_rsc_client = make_rsc_client
}
