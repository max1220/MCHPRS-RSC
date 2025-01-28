#!/usr/bin/env luajit
-- rawvideo.lua
-- This RSC script implements a very simple rawvideo-to-minecraft bridge
--
-- Usage:
-- (Optional) start an X server and start some X clients:
-- $ Xephyr :10 -screen 480x360 & sleep 1 && DISPLAY=:10 xfwm4 & sleep 2 && DISPLAY=:10 firefox-nightly
-- start ffmpeg and this script:
-- $ ffmpeg -video_size 480x360 -framerate 1 -f x11grab -i :10 -c:v rawvideo -f rawvideo -pix_fmt bgr8 - | ./rsc_run_new.lua 127.0.0.1 25566 scripts/rawvideo_new.lua 480 360
-- 
-- You can generate a new `block_palette` by modifying the color_blocks and calling the script with the `--generate_palette` argument

local position = {0,284,0}
local dir = "xpos"

if arg[1] == "--generate_palette" then
	local color_blocks = {
		{ r=114, g=108, b=137, block_id=09359, name="Light Blue Terracotta" },
		{ r=124, g=124, b=114, block_id=12736, name="Light Gray Concrete" },
		{ r=135, g=107, b=098, block_id=09364, name="Light Gray Terracotta" },
		{ r=153, g=153, b=147, block_id=02055, name="Light Gray Wool" },
		{ r=076, g=061, b=092, block_id=09367, name="Blue Terracotta" },
		{ r=048, g=050, b=148, block_id=02058, name="Blue Wool" },
		{ r=097, g=060, b=032, block_id=12740, name="Brown Concrete" },
		{ r=101, g=116, b=051, block_id=09361, name="Lime Terracotta" },
		{ r=099, g=172, b=024, block_id=02052, name="Lime Wool" },
		{ r=078, g=053, b=036, block_id=09368, name="Brown Terracotta" },
		{ r=109, g=067, b=037, block_id=02059, name="Brown Wool" },
		{ r=085, g=089, b=089, block_id=09365, name="Cyan Terracotta" },
		{ r=021, g=141, b=146, block_id=02056, name="Cyan Wool" },
		{ r=158, g=082, b=036, block_id=09357, name="Orange Terracotta" },
		{ r=233, g=106, b=009, block_id=02048, name="Orange Wool" },
		{ r=213, g=101, b=142, block_id=12734, name="Pink Concrete" },
		{ r=008, g=010, b=015, block_id=12743, name="Black Concrete" },
		{ r=205, g=210, b=211, block_id=12728, name="White Concrete" },
		{ r=158, g=076, b=077, block_id=09362, name="Pink Terracotta" },
		{ r=037, g=022, b=016, block_id=09371, name="Black Terracotta" },
		{ r=210, g=180, b=161, block_id=09356, name="White Terracotta" },
		{ r=243, g=149, b=177, block_id=02053, name="Pink Wool" },
		{ r=031, g=031, b=035, block_id=02062, name="Black Wool" },
		{ r=239, g=241, b=241, block_id=02047, name="White Wool" },
		{ r=240, g=174, b=021, block_id=12732, name="Yellow Concrete" },
		{ r=045, g=047, b=143, block_id=12739, name="Blue Concrete" },
		{ r=183, g=130, b=034, block_id=09360, name="Yellow Terracotta" },
		{ r=249, g=202, b=043, block_id=02051, name="Yellow Wool" },
		{ r=054, g=057, b=061, block_id=12735, name="Gray Concrete" },
		{ r=057, g=041, b=035, block_id=09363, name="Gray Terracotta" },
		{ r=073, g=090, b=036, block_id=12741, name="Green Concrete" },
		{ r=076, g=083, b=042, block_id=09369, name="Green Terracotta" },
		{ r=087, g=113, b=024, block_id=02060, name="Green Wool" },
		{ r=166, g=047, b=156, block_id=12730, name="Magenta Concrete" },
		{ r=142, g=033, b=033, block_id=12742, name="Red Concrete" },
		{ r=146, g=086, b=107, block_id=09358, name="Magenta Terracotta" },
		{ r=178, g=058, b=168, block_id=02049, name="Magenta Wool" },
		{ r=140, g=059, b=045, block_id=09370, name="Red Terracotta" },
		{ r=154, g=036, b=033, block_id=02061, name="Red Wool" },
		{ r=224, g=097, b=000, block_id=12729, name="Orange Concrete" },
		{ r=035, g=135, b=197, block_id=12731, name="Light Blue Concrete" },
		{ r=069, g=189, b=224, block_id=02050, name="Light Blue Wool" },
		{ r=101, g=032, b=156, block_id=12738, name="Purple Concrete" },
		{ r=021, g=118, b=134, block_id=12737, name="Cyan Concrete" },
		{ r=116, g=068, b=084, block_id=09366, name="Purple Terracotta" },
		{ r=110, g=035, b=162, block_id=02057, name="Purple Wool" },
		{ r=093, g=166, b=024, block_id=12733, name="Lime Concrete" },
		{ r=069, g=076, b=079, block_id=02054, name="Gray Wool" },
	}
	function closest_wool_color(r,g,b)
		local closest_d = math.huge
		local closest_col
		for _,col in ipairs(color_blocks) do
			local dr = col.r-r
			local dg = col.g-g
			local db = col.b-b
			local w = math.sqrt(dr*dr + dg*dg + db*db)
			if w < closest_d then
				closest_d = w
				closest_col = col
			end
		end
		return closest_col
	end
	print("local block_palette = {")
	for byte=0, 255 do
		local r = bit.band(byte, 0x3) / 3
		local g = bit.rshift(bit.band(byte, 0x1c), 2) / 7
		local b = bit.rshift((bit.band(byte, 0xe0)), 5) / 7
		local closest = closest_wool_color(r*255,g*255,b*255)
		print(("[%.3d] = %d, --%s"):format(byte, closest.block_id, closest.name))
	end
	print("}")
	print("return block_palette")

	os.exit()
end
local block_palette = {
	[000] = 2062,
	2062, 2061, 2061, 2062, 2059, 2061, 2048, 2062, 2060, 2061, 2048, 2060, 2060, 
	2048, 2048, 2060, 2060, 2052, 2048, 2060, 2052, 2052, 2051, 2052, 2052, 2052, 
	2051, 2052, 2052, 2052, 2051, 2062, 2062, 2061, 2061, 2062, 2059, 2061, 2048, 
	2062, 2059, 2061, 2048, 2054, 2060, 2059, 2048, 2060, 2060, 2052, 2048, 2060, 
	2052, 2052, 2051, 2052, 2052, 2052, 2051, 2052, 2052, 2052, 2051, 2062, 2054, 
	2061, 2061, 2062, 2054, 2061, 2048, 2054, 2054, 2061, 2048, 2054, 2060, 2055, 
	2048, 2056, 2060, 2055, 2048, 2056, 2052, 2052, 2051, 2056, 2052, 2052, 2051, 
	2056, 2052, 2051, 2051, 2062, 2058, 2061, 2049, 2058, 2054, 2061, 2049, 2054, 
	2054, 2049, 2053, 2056, 2054, 2055, 2053, 2056, 2055, 2055, 2053, 2056, 2055, 
	2055, 2051, 2056, 2052, 2055, 2051, 2056, 2052, 2055, 2051, 2058, 2057, 2057, 
	2049, 2058, 2058, 2049, 2049, 2058, 2058, 2049, 2049, 2056, 2058, 2055, 2053, 
	2056, 2055, 2055, 2053, 2056, 2055, 2055, 2053, 2056, 2050, 2055, 2053, 2056, 
	2050, 2047, 2047, 2058, 2057, 2057, 2049, 2058, 2057, 2049, 2049, 2058, 2058, 
	2049, 2049, 2056, 2058, 2049, 2053, 2056, 2050, 2055, 2053, 2056, 2050, 2055, 
	2053, 2050, 2050, 2047, 2047, 2050, 2050, 2047, 2047, 2058, 2057, 2057, 2049, 
	2058, 2057, 2049, 2049, 2058, 2057, 2049, 2049, 2056, 2050, 2049, 2053, 2050, 
	2050, 2053, 2053, 2050, 2050, 2047, 2047, 2050, 2050, 2047, 2047, 2050, 2050, 
	2047, 2047, 2058, 2057, 2049, 2049, 2058, 2057, 2049, 2049, 2058, 2057, 2049, 
	2049, 2050, 2050, 2049, 2053, 2050, 2050, 2053, 2053, 2050, 2050, 2047, 2047, 
	2050, 2050, 2047, 2047, 2050, 2050, 2047, 2047,
}

-- input resolution
local input_width = assert(tonumber(arg[1]))
local input_height = assert(tonumber(arg[2]))

if arg[3] then
	block_palette = dofile(arg[3])
end

while true do
	local pixels = io.stdin:read(input_width*input_height)
	local blocks = {}
	for y=input_height-1,0,-1 do
		for x=0, input_width-1 do
			local byte = pixels:byte(y*input_width+x+1)
			local block = block_palette[byte]
			table.insert(blocks, block)
		end
	end
	if dir == "xpos" then
		set_block_range(
			position[1],position[2]-input_height,position[3],
			position[1]+input_width, position[2], position[3]+1,
			blocks
		)
	elseif dir == "zpos" then
		set_block_range(
			position[1],position[2]-input_height,position[3],
			position[1]+1, position[2], position[3]+input_width,
			blocks
		)
	end
end
