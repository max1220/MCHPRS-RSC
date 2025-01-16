-- this RSC script implements a very simple rawvideo-to-minecraft bridge

-- input resolution
local input_width = assert(tonumber(arg[1]))
local input_height = assert(tonumber(arg[2]))

-- required block ids
local wool_black = 2062
local wool_gray = 2054
local wool_light_gray = 2055
local wool_white = 2047

while true do
	local pixels = io.stdin:read(input_width*input_height)
	local blocks = {}
	for y=input_height-1,0,-1 do
		for x=0, input_width-1 do
			local b = pixels:byte(y*input_width+x+1)
			if b > 192 then
				table.insert(blocks, wool_white)
			elseif b > 128 then
				table.insert(blocks, wool_light_gray)
			elseif b > 64 then
				table.insert(blocks, wool_gray)
			else
				table.insert(blocks, wool_black)
			end
		end
	end
	set_block_range(0,30,0, input_width, 30+input_height, 1, blocks)
end
