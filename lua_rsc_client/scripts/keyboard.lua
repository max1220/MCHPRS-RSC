#!/usr/bin/env luajit
-- keyboard.lua
-- This rsc script takes input from a Minecraft pressure plates/levers,
-- and creates X input events using xdotool to emulate key presses.

-- xdotool command and X server to use
local xdotool_cmd = "DISPLAY=:10 xdotool"

-- block IDs
local stone_pressure_place_powered = 5650
local stone_pressure_place_unpowered = 5651
local lever_powered = 5626
local lever_unpowered = 5627

-- position of the clock to observe
local clock_position_x = 119
local clock_position_y = 172
local clock_position_z = 77

-- resolve a block ID to an input state(true = key is down)
local key_state_lut = {
	[stone_pressure_place_powered] = true,
	[stone_pressure_place_unpowered] = false,
	[lever_powered] = true,
	[lever_unpowered] = false,
}

-- keyboard configuration
local keyboard_position_x = 120
local keyboard_position_y = 173
local keyboard_position_z = 65
local keyboard_position_lut = {
	[1] = "Escape",
	[3] = "1",
	[4] = "2",
	[5] = "3",
	[6] = "4",
	[7] = "5",
	[8] = "6",
	[9] = "7",
	[10] = "8",
	[11] = "9",
	[12] = "0",

	[14] = "BackSpace",

	[33] = "q",
	[34] = "w",
	[35] = "e",
	[36] = "r",
	[37] = "t",
	[38] = "z",
	[39] = "u",
	[40] = "i",
	[41] = "o",
	[42] = "p",

	[61] = "Tab",

	[63] = "a",
	[64] = "s",
	[65] = "d",
	[66] = "f",
	[67] = "g",
	[68] = "h",
	[69] = "j",
	[70] = "k",
	[71] = "l",

	[73] = "Return",

	[91] = "Shift_L",

	[93] = "y",
	[94] = "x",
	[95] = "c",
	[96] = "v",
	[97] = "b",
	[98] = "n",
	[99] = "m",
	[100] = "period",
	[101] = "comma",

	[123] = "Control_L",
	[124] = "Alt_L",

	[126] = "space",
	[127] = "space",
	[128] = "space",

	[103] = "Up",
	[117] = "Left",
	[119] = "Right",
	[133] = "Down",

}

-- touchpad configuration
local touchpad_position_x = 140
local touchpad_position_y = 172
local touchpad_position_z = 66
local touchpat_position_lut = {
	[1] = "lmb_hold",
	[3] = "wheel_up",
	[5] = "rmb_hold",

	[8] = "lmb",
	[10] = "wheel_down",
	[12] = "rmb",

	[22] = "rel_-2_-2",
	[23] = "rel_-1_-2",
	[24] = "rel_0_-2",
	[25] = "rel_1_-2",
	[26] = "rel_2_-2",

	[29] = "rel_-2_-1",
	[30] = "rel_-1_-1",
	[31] = "rel_0_-1",
	[32] = "rel_1_-1",
	[33] = "rel_2_-1",

	[36] = "rel_-2_0",
	[37] = "rel_-1_0",
	[38] = "rel_0_0",
	[39] = "rel_1_0",
	[40] = "rel_2_0",

	[43] = "rel_-2_1",
	[44] = "rel_-1_1",
	[45] = "rel_0_1",
	[46] = "rel_1_1",
	[47] = "rel_2_1",

	[50] = "rel_-2_2",
	[51] = "rel_-1_2",
	[52] = "rel_0_2",
	[53] = "rel_1_2",
	[54] = "rel_2_2",
}


-- read the current Minecraft pressure plate/lever state and call callbacks
local function read_state(state, position_lut, x,y,z, w,h,d, on_key_down, on_key_up)
	--print("read_state", state, position_lut, x,y,z, w,h,d, on_key_down, on_key_up)
	state = state or {}
	local blocks = get_block_range(x,y,z, x+w, y+h, z+d)
	for i=1, #blocks do
		local key_name = position_lut[i]
		local key_state = key_state_lut[blocks[i]]
		if key_name and (key_state ~= nil) then
			if state[key_name] ~= key_state then
				state[key_name] = key_state
				if key_state and on_key_down then
					on_key_down(key_name)
				elseif on_key_down then
					on_key_up(key_name)
				end
			end
		elseif not key_name and (key_state ~= nil) then
			print("Unknown key at index:", i, key_state, blocks[i])
		end
	end
	return state
end

-- keyboard key handlers(called when a pressure plate/lever is changed)
local function on_keyboard_key_down(key_name)
	print("key down", key_name)
	os.execute(xdotool_cmd.." keydown "..key_name)
end
local function on_keyboard_key_up(key_name)
	print("key up", key_name)
	os.execute(xdotool_cmd.." keyup "..key_name)
end

-- touchpad key handlers(called when a pressure plate/lever is changed)
local function on_touchpad_key_down(key_name)
	print("touch key down", key_name)
	if key_name == "lmb" then
		os.execute(xdotool_cmd.." mousedown 1")
	elseif key_name == "lmb_hold" then
		os.execute(xdotool_cmd.." mousedown 1")
	elseif key_name == "rmb" then
		os.execute(xdotool_cmd.." mousedown 3")
	elseif key_name == "rmb_hold" then
		os.execute(xdotool_cmd.." mousedown 3")
	elseif key_name == "wheel_up" then
		os.execute(xdotool_cmd.." mousedown 4")
	elseif key_name == "wheel_down" then
		os.execute(xdotool_cmd.." mousedown 5")
	end
end
local function on_touchpad_key_up(key_name)
	print("touch key up", key_name)
	if key_name == "lmb" then
		os.execute(xdotool_cmd.." mouseup 1")
	elseif key_name == "lmb_hold" then
		os.execute(xdotool_cmd.." mouseup 1")
	elseif key_name == "rmb" then
		os.execute(xdotool_cmd.." mouseup 3")
	elseif key_name == "rmb_hold" then
		os.execute(xdotool_cmd.." mouseup 3")
	elseif key_name == "wheel_up" then
		os.execute(xdotool_cmd.." mouseup 4")
	elseif key_name == "wheel_down" then
		os.execute(xdotool_cmd.." mouseup 5")
	end
end

-- read initial keyboard/touchpad state(so we don't send unnecessary keyup event initially)
local keyboard_state = {}
local touchpad_state = {}
read_state(keyboard_state, keyboard_position_lut, keyboard_position_x, keyboard_position_y, keyboard_position_z, 15,1,9)
read_state(touchpad_state, touchpat_position_lut, touchpad_position_x, touchpad_position_y, touchpad_position_z, 7,1,9)

-- move the cursor every iteration based on which touchpad inputs are set
local function update_touchpad()
	for y=-2,2 do
		for x=-2,2 do
			if touchpad_state["rel_"..x.."_"..y] then
				os.execute(xdotool_cmd.." mousemove_relative -- "..x.." "..y)
			end
		end
	end
end

-- observe block changes on the clock
client.send_request.ObserveBlock(clock_position_x,clock_position_y,clock_position_z)

-- read keyboard state and call callbacks
while true do
	local resp = {client.receive_response()}
	if (resp[1] == "ObserveBlockResp") and (resp[2] == clock_position_x) and (resp[3] == clock_position_y) and (resp[4] == clock_position_z) then
		-- clock froze the game, set new clock observer and restart the game
		client.send_request.ObserveBlock(clock_position_x,clock_position_y,clock_position_z)
		unfreeze()
	elseif resp[1] == "ChatMessageResp" then
		-- got chat message request to type string
		os.execute(xdotool_cmd.." type -- "..resp[2])
	else
		error("Unhandled resp:"..tostring(resp[1]))
	end

	-- update the keyboard/touchpad input state and call callbacks and touchpad handler
	read_state(keyboard_state, keyboard_position_lut, keyboard_position_x, keyboard_position_y, keyboard_position_z, 15,1,9, on_keyboard_key_down, on_keyboard_key_up)
	read_state(touchpad_state, touchpat_position_lut, touchpad_position_x, touchpad_position_y, touchpad_position_z, 7,1,9, on_touchpad_key_down, on_touchpad_key_up)
	update_touchpad()
end
