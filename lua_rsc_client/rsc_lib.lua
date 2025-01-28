local ffi = require("ffi")

-- encode the value as the ctype(returns as binary-encoded string)
local function encode_type(ctype, val)
	return ffi.string(ffi.new(ctype.."[1]", val), ffi.sizeof(ctype))
end

-- decode the value in str at i as ctype(returns Lua value if possible)
local function decode_type(ctype, str, i)
	local val = ffi.new(ctype.."[1]")
	local len = ffi.sizeof(ctype)
	ffi.copy(val, str:sub(i, i+len))
	return val[0], len
end

-- get the length of all the header fields in bytes
local function get_header_len(header_fields)
	local header_len = 0
	for _, header in ipairs(header_fields) do
		header_len = header_len + ffi.sizeof(header[2])
	end
	return header_len
end

-- collect request packet types
local request_packet_types = {}
local function add_request_packet_type(name, cmd_id, header_fields, send_body, wait_for_response)
	request_packet_types[cmd_id] = {
		name = name,
		cmd_id = cmd_id,
		header_fields = header_fields,
		header_len = get_header_len(header_fields),
		send_body = send_body,
		wait_for_response = wait_for_response
	}
end

-- collect response packet types
local response_packet_types = {}
local function add_response_packet_type(name, cmd_id, header_fields, receive_body)
	response_packet_types[cmd_id] = {
		name = name,
		cmd_id = cmd_id,
		header_fields = header_fields,
		header_len = get_header_len(header_fields),
		receive_body = receive_body,
	}
end

-- Add request types

add_request_packet_type("GetBlock", 0,
	{
		{"x", "int32_t"},
		{"y", "int32_t"},
		{"z", "int32_t"},
	},
	nil,
	function(client, x,y,z)
		return client.wait_for_response("GetBlockResp", x,y,z, "any")
	end
)

add_request_packet_type("SetBlock", 1, {
	{"x", "int32_t"},
	{"y", "int32_t"},
	{"z", "int32_t"},
	{"block_id", "uint32_t"},
})

add_request_packet_type("ObserveBlock", 2,
	{
		{"x", "int32_t"},
		{"y", "int32_t"},
		{"z", "int32_t"},
	},
	nil,
	function(client, x,y,z)
		return client.wait_for_response("ObserveBlockResp", x,y,z, "any")
	end
)

add_request_packet_type("UpdateBlock", 3, {
	{"x", "int32_t"},
	{"y", "int32_t"},
	{"z", "int32_t"},
})

add_request_packet_type("Freeze", 4, {})

add_request_packet_type("Unfreeze", 5, {})

add_request_packet_type("Step", 6, { {"n", "uint32_t"} })

add_request_packet_type("GetBlockRange", 7,
	{
		{"x_min", "int32_t"},
		{"y_min", "int32_t"},
		{"z_min", "int32_t"},
		{"x_max", "int32_t"},
		{"y_max", "int32_t"},
		{"z_max", "int32_t"},
	},
	nil,
	function(client, x_min, y_min, z_min, x_max, y_max, z_max)
		return client.wait_for_response("GetBlockRangeResp", x_min, y_min, z_min, x_max, y_max, z_max, "any")
	end
)

add_request_packet_type("SetBlockRange", 8,
	{
		{"x_min", "int32_t"},
		{"y_min", "int32_t"},
		{"z_min", "int32_t"},
		{"x_max", "int32_t"},
		{"y_max", "int32_t"},
		{"z_max", "int32_t"},
	},
	function(client, x_min, y_min, z_min, x_max, y_max, z_max, blocks)
		local w = x_max-x_min
		local h = y_max-y_min
		local d = z_max-z_min
		assert((w>0) and (h>0) and (d>0))
		assert(#blocks == w*h*d, ("Expected %d blocks, got %d"):format(w*h*d, #blocks))
		local packet_body = {}
		for _, block in ipairs(blocks) do
			table.insert(packet_body, encode_type("uint32_t", block))
		end
		client.con:send(table.concat(packet_body))
	end
)

add_request_packet_type("UpdateBlockRange", 9, {
	{"x_min", "int32_t"},
	{"y_min", "int32_t"},
	{"z_min", "int32_t"},
	{"x_max", "int32_t"},
	{"y_max", "int32_t"},
	{"z_max", "int32_t"},
})

add_request_packet_type("SendChatMessage", 10, {}, function(client, msg)
	client.con:send(msg.."\000")
end)

add_request_packet_type("GetPlayers", 11, {}, nil, function(client) return client.wait_for_response("GetPlayersResp", "any") end )

add_request_packet_type("Disconnect", 255, {})



-- Add response types

add_response_packet_type("GetBlockResp", 0, {
	{"x", "int32_t"},
	{"y", "int32_t"},
	{"z", "int32_t"},
	{"block_id", "uint32_t"},
})

add_response_packet_type("ObserveBlockResp", 1, {
	{"x", "int32_t"},
	{"y", "int32_t"},
	{"z", "int32_t"},
	{"block_id", "uint32_t"},
})

add_response_packet_type("GetBlockRangeResp", 2,
	{
		{"x_min", "int32_t"},
		{"y_min", "int32_t"},
		{"z_min", "int32_t"},
		{"x_max", "int32_t"},
		{"y_max", "int32_t"},
		{"z_max", "int32_t"},
	}, function(client, x_min,y_min,z_min, x_max,y_max,z_max)
		local blocks = {}
		local blocks_len = (x_max-x_min) * (y_max-y_min) * (z_max-z_min) * 4
		local packet_body = assert(client.con:receive(blocks_len))
		for i=1, blocks_len, 4 do
			local block = decode_type("uint32_t", packet_body, i)
			table.insert(blocks, block)
		end
		return blocks
	end
)

add_response_packet_type("ChatMessageResp", 3, {},
	function(client)
		local msg = {}
		while true do
			local ch = assert(client.con:receive(1))
			if ch=="\000" then break end
			table.insert(msg, ch)
		end
		return table.concat(msg)
	end
)

local player_fields = {
	{ "uuid_hi", "uint64_t"},
	{ "uuid_lo", "uint64_t"},
	{ "pos_x", "double"},
	{ "pos_y", "double"},
	{ "pos_z", "double"},
	{ "yaw", "float"},
	{ "pitch", "float"},
	{ "flying", "uint8_t"},
	{ "sprinting", "uint8_t"},
	{ "crouching", "uint8_t"},
	{ "on_ground", "uint8_t"},
	{ "pos1_x", "int32_t"},
	{ "pos1_y", "int32_t"},
	{ "pos1_z", "int32_t"},
	{ "pos2_x", "int32_t"},
	{ "pos2_y", "int32_t"},
	{ "pos2_z", "int32_t"},
}
local player_fields_len = get_header_len(player_fields)

add_response_packet_type("GetPlayersResp", 4,
	{
		{ "player_count", "uint8_t" },
	},
	function(con, player_count)
		local players = {}
		for _=1, player_count do
			local player_data_str = con:receive(player_fields_len)
			player_data = {}
			local j = 1
			for _, field in ipairs(player_fields) do
				local val, len = decode_type(field[2], player_data_str, j)
				player_data[field[1]] = val
				i = j + len
			end
			local username = {}
			while true do
				local ch = assert(con:receive(1))
				if ch=="\000" then break end
				table.insert(username, ch)
			end
			player_data.username = table.concat(username)
		end
		return players
	end
)






-- create a RSC client object from the TCP connection
local function make_rsc_client(con)
	local client = {}
	client.con = con

	-- determine header lengths for each packet
	for _,request_packet_type in pairs(request_packet_types) do
		request_packet_type.header_len = get_header_len(request_packet_type.header_fields)
	end
	for _,response_packet_type in pairs(response_packet_types) do
		response_packet_type.header_len = get_header_len(response_packet_type.header_fields)
	end

	-- add client.send.* functions to send each request packet type
	client.send_request = {}
	for _,request_packet_type in pairs(request_packet_types) do
		client.send_request[request_packet_type.name] = function(...)
			-- send a binary packet header from supplied arguments
			local packet_header = {string.char(request_packet_type.cmd_id)}
			for i, header in ipairs(request_packet_type.header_fields) do
				table.insert(packet_header, encode_type(header[2], select(i, ...)))
			end
			con:send(table.concat(packet_header))

			-- send the body for the packet if needed
			if request_packet_type.send_body then
				request_packet_type.send_body(client, ...)
			end

			-- return a function to resolve the response if any
			local orig_args, orig_len = {...}, select("#", ...)
			if request_packet_type.wait_for_response then
				return function()
					return request_packet_type.wait_for_response(client, unpack(orig_args, 1, orig_len))
				end
			end
		end
	end

	-- receive and decode the next packet
	function client.receive_response()
		local response = {}

		-- wait for the command ID to identify the packet type
		local cmd_id = (con:receive(1) or ""):byte()
		if not cmd_id then return end
		local response_packet_type = response_packet_types[cmd_id]
		if not response_packet_type then error("Unknown response from server: "..cmd_id); end

		-- receive the packet header
		local packet_header = con:receive(response_packet_type.header_len)
		local i = 1
		for _, header in ipairs(response_packet_type.header_fields) do
			local val, len = decode_type(header[2], packet_header, i)
			table.insert(response, val)
			i = i + len
		end

		-- receive packet body if any
		if response_packet_type.receive_body then
			table.insert(response, response_packet_type.receive_body(client, unpack(response)))
		end

		-- return received packet
		return response_packet_type.name, unpack(response)
	end

	-- wait for a specific response packet(discards other packets!)
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

	return client
end

return {
	make_rsc_client = make_rsc_client
}