local function capture_args(...) t = {...}; t.n = select("#", ...); return t end
local function measure(f, ...)
	local time = require("time")
	local start = time.gettime()
	local ret = capture_args(f(...))
	local stop = time.gettime()
	return stop-start, unpack(ret, 1, ret.n)
end

local function test()
	print("id: ", get_block(0,0,0))
	print("id: ", get_block(0,1,0))
	print("id: ", get_block(0,2,0))
	print("id: ", get_block(0,3,0))
	print("id: ", get_block(0,4,0))
	print("id: ", get_block(0,5,0))
	print("id: ", get_block(0,6,0))
	print("id: ", get_block(0,7,0))
	return true
end

local dt,ret = measure(test)

print()
print("test returned:",ret)
print("Took:",dt*1000, "ms")
