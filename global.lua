print("LUA FILE LOAD")

function on_load(plot)
	print("LUA PLOT LOAD", plot)

	for y=1, 100 do
		plot:setBlockID(1,y,1, 128)
	end

end

function on_chat(plot, player, command, args)
	print("LUA PLOT COMMAND", plot, player, command, args)
end

function on_tick(plot)
	--print("ON PLOT TICK", plot)
end
