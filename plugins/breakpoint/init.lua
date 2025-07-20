--[[
This script implements a Lua REPL plugin, supporting  a Minecraft chat command(`/lua`).

THIS SCRIPT IS DANGEROUS TO RUN ON PUBLIC SERVERS! SEE WARNING IN README.md!

]]

local plugin = {
	name = "Redstone Breakpoints",
	description = "Observe changes in blocks and tick-freeze the game",
	version = { 0, 0, 1 },

	breakpoints = {},
}


function plugin:add_breakpoint(name, x, y, z, current_block_id, action)
	local breakpoint = {
		x = assert(tonumber(x)),
		y = assert(tonumber(y)),
		z = assert(tonumber(z)),
		name = tostring(assert(name)),
		last_block_id = assert(tonumber(current_block_id)),
		action = action
	}
	self.breakpoints[name] = breakpoint
	return breakpoint
end

function plugin:remove_breakpoint(name)
	self.breakpoints[name] = nil
end

local function print_chat(plot, player_uuid, ...)
	local str = {}
	for i = 1, select("#", ...) do
		table.insert(str, tostring((select(i, ...))))
	end
	plot:sendChatMessage(player_uuid, table.concat(str, "  "))
end

function plugin:command_add(plot, player_uuid, args)
	local name = table.remove(args, 1)
	if not name then
		plot:sendChatMessage(player_uuid, "Requires at least a single argument! Try /breakpoint help")
		return
	end
	local action = function(self, plot, new_block_id)
		print_chat(plot, player_uuid, name .. "(" .. new_block_id .. ")")
	end
	if name:sub(1, 1) == "#" then
		name = name:sub(2)
		action = function(self, plot, new_block_id)
			plot:setDisableTicking(true)
			plot:sendChatMessage(player_uuid, name .. "(" .. new_block_id .. "): Plot is frozen")
		end
	elseif (name:sub(1, 1) == "!") and self.config.allow_lua_action then
		name = name:sub(2)
		local ok, outer_func, err = pcall(loadstring,
			"return function(breakpoint, plot, new_block_id) " .. table.concat(args, " ") .. " end")
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
		action = inner_func
	end

	if #args == 0 then
		local player = plot:listPlayers()[player_uuid]
		local x, y, z = math.floor(player.x), math.floor(player.y), math.floor(player.z)
		local block_id = plot:getBlockID(x, y, z)
		self:add_breakpoint(name, x, y, z, block_id, action)
	elseif #args == 3 then
		local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	else

	end
end

function plugin:command_list(plot, player_uuid, args)
	local breakpoints_list = {}
	for _, breakpoint in pairs(self.breakpoints) do
		table.insert(breakpoints_list,
			("%s(%d, %d, %d)"):format(breakpoint.name, breakpoint.x, breakpoint.y, breakpoint.z))
	end
	table.sort(breakpoints_list)
	print_chat(plot, player_uuid, "Breakpoints:\n" .. table.concat(breakpoints_list, "\n"))
end

function plugin:command_remove(plot, player_uuid, args)
	local breakpoint_name = args[1]
	if not breakpoint_name then
		print_chat(plot, player_uuid, "Need the breakpoint name!")
		return
	end
	if not self.breakpoints[breakpoint_name] then
		print_chat(plot, player_uuid, "Breakpoint not found!")
		return
	end
	self:remove_breakpoint(breakpoint_name)
end

function plugin:command_freeze(plot, player_uuid, args)
	plot:setDisableTicking(true)
	plot:sendChatMessage(player_uuid, "Plot is frozen")
end

function plugin:command_unfreeze(plot, player_uuid, args)
	plot:setDisableTicking(false)
	plot:sendChatMessage(player_uuid, "Plot is unfrozen")
end

function plugin:command_help(plot, player_uuid)
	print_chat(plot, player_uuid,
		"/breakpoint help: shows this message \n",
		"/breakpoint add [name] [x] [y] [z]: adds a breakpoint. x,y,z defaults to player position\n" ..
		"/breakpoint list: Lists all breakpoints \n" ..
		"/breakpoint remove [name]: removes a breakpoint \n" ..
		"/breakpoint freeze: Freezes the plot updates \n" ..
		"/breakpoint unfreeze: Unfreezes the plot updates \n"
	)
end

function plugin:on_command(plot, player_uuid, command, args)
	if command ~= "breakpoint" then return false; end
	command = table.remove(args, 1)
	local command_handler = self["command_" .. command]
	if command_handler then
		command_handler(self, plot, player_uuid, unpack(args))
	else
		plot:sendChatMessage(player_uuid, "Unknown /breakpoint command! Try /breakpoint help")
	end
	return true
end

function plugin:on_tick(plot)
	for _, breakpoint in ipairs(self.breakpoints) do
		local block_id = plot:getBlockID(breakpoint.x, breakpoint.y, breakpoint.z)
		if block_id ~= breakpoint.last_block_id then
			breakpoint:action(plot, block_id)
		end
		breakpoint.last_block_id = block_id
	end
end

return plugin
