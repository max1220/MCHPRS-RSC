-- this RSC script implements a very simple rawvideo-to-minecraft bridge

-- input resolution
local input_width = 80
local input_height = 60

-- required block ids
local wool_black = 2062
local wool_gray = 2054
local wool_light_gray = 2055
local wool_white = 2047

while true do
	local pixels = io.stdin:read(input_width*input_height)
	for y=1, input_height-1 do
		for x=1, input_width-1 do
			local b = pixels:byte(y*input_width+x)
			if b > 192 then
				set_block(wool_white, x,100-y,0)
			elseif b > 128 then
				set_block(wool_light_gray, x,100-y,0)
			elseif b > 64 then
				set_block(wool_gray, x,100-y,0)
			else
				set_block(wool_black, x,100-y,0)
			end
			--update_block(x,y,0)
		end
	end
end
