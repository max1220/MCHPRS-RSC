#!/usr/bin/env luajit
-- Lua RSC script runner(send RSC commands to MCHPRS Minecraft server from Lua).
local socket = require("socket")
local rsc_lib = require("rsc_lib")

-- connect to MCHPRS RSC port as client
local tcp = socket.tcp()
local addr = assert(table.remove(arg, 1), "First command-line argument needs to be listen address!")
local port = assert(table.remove(arg, 1), "Second command-line argument needs to be listen port!")
assert(tcp:connect(addr, port), ("Can't connect to: %q with port: %d"):format(tostring(addr), tostring(port)))

-- create a RSC client
client = rsc_lib.make_rsc_client(tcp)

-- export functions to global namespace()
for k,v in pairs(client) do _G[k] = v end

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
