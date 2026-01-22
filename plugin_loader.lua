
--[[
This file implements a Lua plugin loader.

You should put plugins into the `plugins/` directory, and configure them
in the `plugins/init.lua` file. 

]]

info("Plugin loader started!")

-- lists of callback handlers.
local handlers = {
	on_tick = {},
	on_chat = {},
	on_command = {},
	on_join = {},
	on_leave = {},
	on_disconnect = {},
	on_shutdown = {},
	on_load = {},
}

-- list of all loaded plugins
local plugins = {}

-- methods/fields overloaded for all plugins
local plugin_overload = {}
function plugin_overload:info(...)
	local str = {}
	for i=1, select("#", ...) do
		table.insert(str, tostring(select(i, ...)))
	end
	info(self.name .. ": " .. table.concat(str, " "))
end
function plugin_overload:warn(...)
	local str = {}
	for i=1, select("#", ...) do
		table.insert(str, tostring(select(i, ...)))
	end
	warn(self.name .. ": " .. table.concat(str, " "))
end
function plugin_overload:err(...)
	local str = {}
	for i=1, select("#", ...) do
		table.insert(str, tostring(select(i, ...)))
	end
	err(self.name .. ": " .. table.concat(str, " "))
end

-- this global function is used to load a plugin, and internally wraps a call to require(plugin_name).
function load_plugin(plugin_name, config)
	if plugins[plugin_name] then
		return plugins[plugin_name]
	end
	local ok,plugin = pcall(require, "plugins."..plugin_name..".init")
	if not ok then
		err("Can't load plugin '"..plugin_name.."': "..tostring(plugin))
		return
	end
	table.insert(plugins, plugin)
	plugins[plugin_name] = plugin
	for handler_name, handler_list in pairs(handlers) do
		if plugin[handler_name] then
			table.insert(handler_list, { func=plugin[handler_name], plugin=plugin })
		end
	end
	for k,v in pairs(config or {}) do
		plugin.config[k] = v
	end
	for k,v in pairs(plugin_overload) do
		plugin[k] = v
	end
	info("Loaded plugin: "..plugin_name)
	if plugin.on_plugin_load then
		plugin:on_plugin_load(config)
	end
	return plugin
end

-- pcall wrapper that logs errors using err function
local function pcall_wrap(name, fn, ...)
	return (function(ok, ...)
		if not ok then
			err(name .. ": Error: "..tostring(select(1, ...)))
		end
		return ok, ...
	end)(xpcall(fn, debug.traceback, ...))
end

-- load the user-configured list of plugins
pcall_wrap("plugin list", require, "plugins.init")

-- these callbacks forward a call to all loaded plugins
function on_tick(...) for _, handler in ipairs(handlers.on_tick) do pcall_wrap("on_tick",handler.func, handler.plugin, ...) end end
function on_chat(...) for _, handler in ipairs(handlers.on_chat) do pcall_wrap("on_chat",handler.func, handler.plugin, ...) end end
function on_join(...) for _, handler in ipairs(handlers.on_join) do pcall_wrap("on_join",handler.func, handler.plugin, ...) end end
function on_leave(...) for _, handler in ipairs(handlers.on_leave) do pcall_wrap("on_leave",handler.func, handler.plugin, ...) end end
function on_disconnect(...) for _, handler in ipairs(handlers.on_disconnect) do pcall_wrap("on_disconnect",handler.func, handler.plugin, ...) end end
function on_shutdown(...) for _, handler in ipairs(handlers.on_shutdown) do pcall_wrap("on_shutdown",handler.func, handler.plugin, ...) end end
function on_load(...) for _, handler in ipairs(handlers.on_load) do pcall_wrap("on_load",handler.func, handler.plugin, ...) end end

-- command callbacks are special:
-- the /plugin command can't be handled by any other command,
-- and the first command handler that returns truethy terminates the callback chain.
function on_command(plot, player_uuid, command, args)
	if command == "plugins" then
		local plugin_list = {}
		for _, plugin in ipairs(plugins) do
			table.insert(plugin_list, ("%s(%d.%d.%d): %s"):format(plugin.name, plugin.version[1], plugin.version[2], plugin.version[3], plugin.description))
		end
		plot:sendChatMessage(player_uuid, "Plugins:\n"..table.concat(plugin_list, "\n"))
		return true
	end
	for _, handler in ipairs(handlers.on_command) do
		local ok, ret = pcall_wrap("on_command", handler.func, handler.plugin, plot, player_uuid, command, args)
		if ok and ret then return true end
	end
end
