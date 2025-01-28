#!/usr/bin/env luajit
-- Lua RSC script runner(send RSC commands to MCHPRS Minecraft server from Lua).
local socket = require("socket")
local rsc_lib = require("rsc_lib")

-- connect to MCHPRS RSC port as client
local tcp = socket.tcp()
local addr = assert(table.remove(arg, 1), "First command-line argument needs to be address!")
local port = assert(table.remove(arg, 1), "Second command-line argument needs to be port!")
assert(tcp:connect(addr, port), ("Can't connect to: %q with port: %d"):format(tostring(addr), tostring(port)))

-- create a RSC client
client = rsc_lib.make_rsc_client(tcp)

-- create global shortcut functions
function set_block(...) return client.send_request.SetBlock(...) end
function get_block(...) return select(5, client.send_request.GetBlock(...)()) end
function observe_block(...) return select(5, client.send_request.ObserveBlock(...)()) end
function update_block(...) return client.send_request.UpdateBlock(...) end
function freeze(...) return client.send_request.Freeze(...) end
function unfreeze(...) return client.send_request.Unfreeze(...) end
function step(...) return client.send_request.Step(...) end
function get_block_range(...) return select(8, client.send_request.GetBlockRange(...)()) end
function set_block_range(...) return client.send_request.SetBlockRange(...) end
function update_block_range(...) return client.send_request.UpdateBlockRange(...) end
function send_chat_message(...) return select(2, client.send_request.SendChatMessage(...)) end
function get_players(...) return select(2, client.send_request.GetPlayers(...)()) end
function receive_response() return client.receive_response() end


-- either run a script(if provided), or drop to an interactive debug shell
local script_path = table.remove(arg, 1)
if script_path then
	dofile(script_path)
else
	print([[
No script file argument provided! Running in interactive mode(Lua REPL).

Available functions:
 * set_block(id, x,y,z)       -- write block
 * id = get_block(x,y,z)      -- read block
 * id = observe_block(x,y,z)  -- wait for block change
 * update_block(x,y,z)        -- update (surrounding) blocks after set
 * freeze()                   -- disable redstone ticking
 * unfreeze()                 -- enable redstone ticking
 * step(n)                    -- run n redstone ticks
 * blocks = get_block_range(x0,y0,z0,x1,y1,z1)  -- read range of blocks
 * set_block_range(x0,y0,z0,x1,y1,z1, blocks)   -- write range of blocks
 * update_block_range(x0,y0,z0,x1,y1,z1)        -- update range of blocks(after set)
 * send_chat_message(msg)     -- send chat message
 * players = get_players()    -- get list of player data

Additionally, the RSC client object is available in the global `client`.
]])
	debug.debug()
end
