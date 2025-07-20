--[[
This script implements a Lua REPL plugin, supporting  a Minecraft chat command(`/lua`).

THIS SCRIPT IS DANGEROUS TO RUN ON PUBLIC SERVERS! SEE WARNING IN README.md!

]]

local plugin = {
	name = "Lua REPL",
	description = "A simple Lua REPL implementing the /lua command",
	version = {0,0,1},
}

-- adapted from: http://lua-users.org/wiki/TableSerialization
local to_string
local function table_print(tbl, indent, done)
	done = done or {}
	indent = indent or 0
	if type(tbl) == "table" then
		local sb = {}
		for key, value in pairs(tbl) do
			table.insert(sb, string.rep(" ", indent))
			local index = "[" .. to_string(key, indent, done) .. "] = "
			if (type(key)=="string") and key:match("^[%w_]+$") then
				index = key .. " = "
			end
			if type(value) == "table" and not done[value] then
				done[value] = true
				table.insert(sb, index .. "{\n");
				table.insert(sb, table_print(value, indent + 1, done))
				table.insert(sb, string.rep(" ", indent))
				table.insert(sb, "}\n");
			elseif "number" == type(key) then
				table.insert(sb, to_string(value, indent, done))
			else
				table.insert(sb, index .. to_string(value, indent, done) .. "\n")
			end
		end
		return table.concat(sb)
	else
		return tbl .. "\n"
	end
end
to_string = function(any, indent, done)
	if "nil" == type(any) then
		return tostring(nil)
	elseif "table" == type(any) then
		return "{\n" .. table_print(any, indent, done) .. "}"
	elseif "string" == type(any) then
		return ("%q"):format(any)
	else
		return tostring(any)
	end
end

-- output a chat message for the specified player only(nicely formats arguments)
local function print_chat(plot, player_uuid, ...)
	local str = {}
	for i = 1, select("#", ...) do
		table.insert(str, to_string((select(i, ...))))
	end
	plot:sendChatMessage(player_uuid, table.concat(str, "  "))
end

-- warn the server operator that a potentially dangerous plugin has been loaded
function plugin:on_plugin_load()
	self:warn("The REPL script allows any user to execute arbitrary Lua code via chat command! This might be dangerous.")
end

-- implement the actual /lua command
function plugin:on_command(plot, player_uuid, command, args)
	if command ~= "lua" then return false; end
	local str = table.concat(args, " ")
	if str:sub(1,1) == "=" then str = "return " .. str:sub(2) end
	local ok, outer_func, err = pcall(loadstring, "return function(plot, player_uuid) " .. str .. " end")
	if not ok then
		print_chat(plot, player_uuid, "Error", outer_func);
		return true
	elseif not outer_func then
		print_chat(plot, player_uuid, "Error", err);
		return true
	end
	local ok, inner_func = pcall(outer_func)
	if not ok then
		print_chat(plot, player_uuid, "Error", inner_func);
		return true
	end
	(function(plot, player_uuid, ok, ...)
		if ok then
			if select(1, ...) ~= nil then
				print_chat(plot, player_uuid, "Ok", ...)
			end
		else
			print_chat(plot, player_uuid, "Error", ...)
		end
	end)(plot, player_uuid, pcall(inner_func, plot, player_uuid))
	return true
end

return plugin
