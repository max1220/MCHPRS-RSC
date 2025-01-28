#!/usr/bin/env luajit



-- ### CONFIGURATION ###

-- RSC server to connect to
local rsc_addr, rsc_port = "127.0.0.1", 25566

-- ### END CONFIGURATION ###



-- Lua RSC script runner(send RSC commands to MCHPRS Minecraft server from Lua).
local socket = require("socket")
local json = require("cjson")
local rsc_lib = dofile("../../rsc_lib.lua") -- adjust to your needs

-- exit with error message
local function err_exit(err_msg)
	print("Status: 400 Bad Request");
	print("Content-type: application/json")
	print()
	print(json.encode({ status="err", err = err_msg }))
	os.exit(1)
end

-- assert that uses err_exit
local function _assert(test, ...)
	if (test == nil) or (test == false) then err_exit(...) end
	return test, ...
end

-- reply with JSON response
local function json_resp(data)
	print("Content-type: application/json")
	print()
	print(json.encode(data))
end

-- parse a query string from QUERY_STRING env var(GET) or stdin(POST)
local function parse_query(query_str)
	local query_args = {}
	local function hex_to_char(hex_ch) return string.char(tonumber(hex_ch, 16)) end
	for key,val in query_str:gmatch("([^&=?]-)=([^&=?]+)") do
		key = key:gsub("%%(%x%x)", hex_to_char):gsub("%+", " ")
		val = val:gsub("%%(%x%x)", hex_to_char):gsub("%+", " ")
		query_args[key] = val
	end
	return query_args
end

-- parse QUERY_STRING
local method = assert(os.getenv("REQUEST_METHOD"), "Need a REQUEST_METHOD(run as CGI script)")
local query_args
if method =="GET" then
	query_args = parse_query(assert(os.getenv("QUERY_STRING")))
elseif method == "POST" then
	query_args = parse_query(io.stdin:read("*a"))
else
	err_exit("Method not supported")
end

-- connect to MCHPRS RSC TCP port as client
local tcp = socket.tcp()
_assert(tcp:connect(rsc_addr, rsc_port))

-- create the protocol client for the connection
local client = rsc_lib.make_rsc_client(tcp)

-- parse the command and run it
if query_args.command == "set_block" then
	local block_id = _assert(tonumber(query_args.block_id), "missing/invalid block_id")
	local x = _assert(tonumber(query_args.x), "missing/invalid x")
	local y = _assert(tonumber(query_args.y), "missing/invalid y")
	local z = _assert(tonumber(query_args.z), "missing/invalid z")
	client.send_request.SetBlock(block_id, x, y, z)
	json_resp({ command=query_args.command, status="ok" })
elseif query_args.command == "get_block" then
	local x = _assert(tonumber(query_args.x), "missing/invalid x")
	local y = _assert(tonumber(query_args.y), "missing/invalid y")
	local z = _assert(tonumber(query_args.z), "missing/invalid z")
	local block_id = select(5, client.send_request.GetBlock(x,y,z)())
	json_resp({ command=query_args.command, status="ok", block_id=block_id })
elseif query_args.command == "observe_block" then
	local x = _assert(tonumber(query_args.x), "missing/invalid x")
	local y = _assert(tonumber(query_args.y), "missing/invalid y")
	local z = _assert(tonumber(query_args.z), "missing/invalid z")
	local block_id = select(5, client.send_request.ObserveBlock(x,y,z)())
	json_resp({ command=query_args.command, status="ok", block_id=block_id })
elseif query_args.command == "update_block" then
	local x = _assert(tonumber(query_args.x), "missing/invalid x")
	local y = _assert(tonumber(query_args.y), "missing/invalid y")
	local z = _assert(tonumber(query_args.z), "missing/invalid z")
	client.send_request.UpdateBlock(x, y, z)
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "freeze" then
	client.send_request.Freeze()
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "unfreeze" then
	client.send_request.Unfreeze()
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "step" then
	local n = _assert(tonumber(query_args.n), "missing/invalid n")
	client.send_request.Step(n)
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "get_block_range" then
	local x_min = _assert(tonumber(query_args.x_min), "missing/invalid x_min")
	local y_min = _assert(tonumber(query_args.y_min), "missing/invalid y_min")
	local z_min = _assert(tonumber(query_args.z_min), "missing/invalid z_min")
	local x_max = _assert(tonumber(query_args.x_max), "missing/invalid x_max")
	local y_max = _assert(tonumber(query_args.y_max), "missing/invalid y_max")
	local z_max = _assert(tonumber(query_args.z_max), "missing/invalid z_max")
	local w,h,d = x_max-x_min, y_max-y_min, z_max-z_min
	_assert((w>0) and (h>0) and (d>0), "Invalid block range!")
	local blocks = client.send_request.GetBlockRange(x_min,y_min,z_min, x_max,y_max,z_max)()
	json_resp({ command=query_args.command, status="ok", blocks=blocks})
elseif query_args.command == "set_block_range" then
	local x_min = _assert(tonumber(query_args.x_min), "missing/invalid x_min")
	local y_min = _assert(tonumber(query_args.y_min), "missing/invalid y_min")
	local z_min = _assert(tonumber(query_args.z_min), "missing/invalid z_min")
	local x_max = _assert(tonumber(query_args.x_max), "missing/invalid x_max")
	local y_max = _assert(tonumber(query_args.y_max), "missing/invalid y_max")
	local z_max = _assert(tonumber(query_args.z_max), "missing/invalid z_max")
	local w,h,d = x_max-x_min, y_max-y_min, z_max-z_min
	_assert((w>0) and (h>0) and (d>0), "Invalid block range!")
	local blocks = {}
	_assert(query_args.blocks, "missing blocks!")
	for id in (query_args.blocks..","):gmatch("(.-),") do
		table.insert(blocks, _assert(tonumber(id), "Block ID not a number!"))
	end
	_assert(#blocks == w*h*d, ("Dimensions and #blocks received don't match! Got %d blocks, expected %d"):format(#blocks, w*h*d))
	client.send_request.SetBlockRange(x_min,y_min,z_min, x_max,y_max,z_max, blocks)
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "update_block_range" then
	local x_min = _assert(tonumber(query_args.x_min), "missing/invalid x_min")
	local y_min = _assert(tonumber(query_args.y_min), "missing/invalid y_min")
	local z_min = _assert(tonumber(query_args.z_min), "missing/invalid z_min")
	local x_max = _assert(tonumber(query_args.x_max), "missing/invalid x_max")
	local y_max = _assert(tonumber(query_args.y_max), "missing/invalid y_max")
	local z_max = _assert(tonumber(query_args.z_max), "missing/invalid z_max")
	local w,h,d = x_max-x_min, y_max-y_min, z_max-z_min
	_assert((w>0) and (h>0) and (d>0), "Invalid block range!")
	client.send_request.UpdateBlockRange(x_min,y_min,z_min, x_max,y_max,z_max)
	json_resp({ command=query_args.command, status="ok"})
elseif query_args.command == "send_chat_message" then
	local msg = _assert(query_args.msg, "missing chat message")
	client.send_request.SendChatMessage(msg)
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "get_players" then
	local players = client.send_request.GetPlayers()()
	json_resp({ command=query_args.command, status="ok", players=players})
else
	err_exit("missing/invalid command!")
end

-- gracefully shutdown connection
client.disconnect()
