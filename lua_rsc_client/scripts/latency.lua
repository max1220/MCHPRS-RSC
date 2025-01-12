local time = require("time")

local function capture_args(...) local t = {...}; t.n = select("#", ...); return t end
local function measure(f, ...)
	local start = time.gettime()
	local ret = capture_args(f(...))
	return time.gettime()-start, unpack(ret, 1, ret.n)
end

while true do
	print(measure(get_block, 0,0,0)*1000)
end
