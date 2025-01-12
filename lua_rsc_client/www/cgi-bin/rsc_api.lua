#!/usr/bin/env luajit

-- ### CONFIGURATION ###

-- RSC server to connect to
local rsc_addr, rsc_port = "127.0.0.1", 25566

-- ### END CONFIGURATION ###

-- Lua RSC script runner(send RSC commands to MCHPRS Minecraft server from Lua).
local socket = require("socket")
local json = require("cjson")
local rsc_lib = dofile("../../rsc_lib.lua")

-- exit with error message
local function err_exit(err_msg)
	print("Content-type: application/json")
	print("Status: 400 Bad Request");
	print()
	print(json.encode({ err = err_msg }))
	os.exit(1)
end

-- assert that uses err_exit
local function _assert(test, ...)
	if test then return test, ... end
	err_exit(...)
end

-- reply with JSON response
local function json_resp(data)
	print("Content-type: application/json")
	print()
	print(json.encode(data))
	os.exit(0)
end

-- parse the QUERY_STRING
local function parse_query(query_str)
	local query_args = {}
	local function hex_to_char(hex_ch) return string.char(tonumber(hex_ch, 16)) end
	for key,val in query_str:gmatch("([^&=?]-)=([^&=?]+)") do
		key = key:gsub("%%(%x%x)", hex_to_char)
		val = val:gsub("%%(%x%x)", hex_to_char)
		query_args[key] = val
	end
	return query_args
end

-- parse QUERY_STRING
local query_str = assert(os.getenv("QUERY_STRING"), "Needs a QUERY_STRING(run as CGI script)")
local query_args = parse_query(query_str)

-- connect to MCHPRS RSC TCP port as client
local tcp = socket.tcp()
_assert(tcp:connect(rsc_addr, rsc_port))

-- create the protocol client for the connection
local client = rsc_lib.make_rsc_client(tcp)

-- parse the command and run it
if query_args.command == "set_block" then
	local block_id = _assert(tonumber(query_args.block_id), "missing block_id")
	local x = _assert(tonumber(query_args.x), "missing x")
	local y = _assert(tonumber(query_args.y), "missing y")
	local z = _assert(tonumber(query_args.z), "missing z")
	client.set_block(block_id, x, y, z)
	json_resp({ command=query_args.command, status="ok" })
elseif query_args.command == "get_block" then
	local x = _assert(tonumber(query_args.x), "missing x")
	local y = _assert(tonumber(query_args.y), "missing y")
	local z = _assert(tonumber(query_args.z), "missing z")
	local block_id = client.get_block(x, y, z)
	json_resp({ command=query_args.command, status="ok", block_id=block_id })
elseif query_args.command == "observe_block" then
	local x = _assert(tonumber(query_args.x), "missing x")
	local y = _assert(tonumber(query_args.y), "missing y")
	local z = _assert(tonumber(query_args.z), "missing z")
	local block_id = client.observe_block(x, y, z)
	json_resp({ command=query_args.command, status="ok", block_id=block_id })
elseif query_args.command == "update_block" then
	local block_id = _assert(tonumber(query_args.block_id))
	local x = _assert(tonumber(query_args.x), "missing x")
	local y = _assert(tonumber(query_args.y), "missing y")
	local z = _assert(tonumber(query_args.z), "missing z")
	client.set_block(block_id, x, y, z)
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "freeze" then
	client.freeze()
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "unfreeze" then
	client.unfreeze()
	json_resp({ command=query_args.command, status="ok",})
elseif query_args.command == "step" then
	local n = _assert(tonumber(query_args.n), "missing n")
	client.step(n)
	json_resp({ command=query_args.command, status="ok",})
else
	err_exit("Unknown command!")
end
