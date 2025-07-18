--[[
This script implements a Lua REPL as a Minecraft chat command(`/lua`).

THIS SCRIPT IS DANGEROUS TO RUN ON PUBLIC SERVERS! SEE WARNING IN README.md!

]]


-- adapted from: http://lua-users.org/wiki/TableSerialization
function table_print(tbl, indent, done)
	done = done or {}
	indent = indent or 0
	if type(tbl) == "table" then
		local sb = {}
		for key, value in pairs(tbl) do
			table.insert(sb, string.rep(" ", indent))
			local index = "[" .. to_string(key) .. "] = "
			if (type(key)=="string") and key:match("^[%w_]+$") then
				index = key .. " = "
			end
			if type(value) == "table" and not done[value] then
				done[value] = true
				table.insert(sb, index .. "{\n");
				table.insert(sb, table_print(value, indent + 2, done))
				table.insert(sb, string.rep(" ", indent))
				table.insert(sb, "}\n");
			elseif "number" == type(key) then
				table.insert(sb, to_string(value))
			else
				table.insert(sb, index .. to_string(value) .. "\n")
			end
		end
		return table.concat(sb)
	else
		return tbl .. "\n"
	end
end
function to_string(any, indent, done)
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

local function print_chat(plot, player_uuid, ...)
	local str = {}
	for i = 1, select("#", ...) do
		table.insert(str, to_string(select(i, ...)))
	end
	plot:sendChatMessage(player_uuid, table.concat(str, "  "))
end

local function print_pcall_res(plot, player_uuid, ok, ...)
	if ok then
		print_chat(plot, player_uuid, "Ok", ...)
	else
		print_chat(plot, player_uuid, "Error:", ...)
	end
end

function on_load(plot)
	print("WARNING: Lua REPL loaded!")
end

function on_command(plot, player_uuid, command, args)
	if command ~= "lua" then return false; end
	local str = table.concat(args, " ")
	local func, err = loadstring("return function(plot, player_uuid) " .. str .. " end", "/lua command")
	if not func then
		print_chat("Error:", err);
		return true
	end
	local ok, ret = pcall(func)
	if ok then
		print_pcall_res(plot, player_uuid, pcall(ret, plot, player_uuid))
	else
		print_chat("Error:", ret)
	end
	return true
end
