-- this RSC script implements a simple memory

-- configuration of the redstone memory
local config = {
	clock_pos = {50,24,26}, -- position of redstone dot for clock
	enable_write = true, -- if writes to memory are enabled
	write_enable_pos = {50,24,28}, -- position of redstone dot write enable signal
	addr_bit_count = 8, -- address bits(count of redstone dots in address tower)
	addr_pos = {50,24,30}, -- position of redstone dot address tower
	data_bit_count = 8, -- data bits(count of redstone dots in data input/output towers)
	din_pos = {50,24,32}, -- position of redstone dot data input tower
	dout_pos = {50,25,34}, -- position of redstone dot data output tower
}

-- required block ids
local block_ids = {
	redstone_dot_0 = 4138,
	redstone_dot_15 = 4273,
	lever_west_on = 5638,
	lever_west_off = 5639,
	trapdoor_east_on = 10448,
	trapdoor_east_off = 10454,
}



-- memory storage used by the redstone build.
-- unused cells default to returning 0
local memory = setmetatable({}, {
	__index = function (t, k) return 0 end,
})

-- load file from argument if any
local file_arg = table.remove(arg, 1)
if file_arg then
	local f = assert(io.open(file_arg, "rb"))
	local d = f:read("*a")
	f:close()
	for i=1, #d do
		memory[i-1] = d:byte(i,i)
	end
end

-- read a redstone dot as a boolean value
local function read_trapdoor_east(x, y, z)
	return get_block(x, y, z) == block_ids.trapdoor_east_on
end

-- write the boolean state to the west-facing lever
local function write_lever_west(state, x, y, z)
	set_block((state and block_ids.lever_west_on) or block_ids.lever_west_off, x,y,z)
	update_block(x, y, z)
	update_block(x+1, y, z)
end

-- wait for the clock redstone dot to become high
local function wait_for_clock(x, y, z)
	while observe_block(x, y, z) ~= block_ids.trapdoor_east_on do
		unfreeze()
	end
end

-- read a stack of redstone dots
local function read_ystack(ystep, count, x, y, z)
	local data = {}
	for yo=0, count-1 do
		table.insert(data, read_trapdoor_east(x, y+yo*ystep, z))
	end
	return data
end

-- write a stack of levers froma list of booleans
local function write_ystack(ystep, data, x, y, z)
	for i=1, #data do
		write_lever_west(data[i], x, y+(i-1)*ystep, z)
	end
end

-- convert table of bits to integer
function bits_to_n(bits, reverse)
	local n = 0
	for i=1, #bits do
		local bit = bits[i]
		if bit and reverse then
			n = n + 2^(#bits-i)
		elseif bit then
			n = n + 2^(i-1)
		end
	end
	return n
end

-- convert integer to table of bits
function n_to_bits(n, bit_count, reverse)
	local bits = {}
	for i=1, bit_count do
		local insert_i = (reverse and 1) or (#bits+1)
		if n % 2 == 0 then
			table.insert(bits, insert_i, false)
		else
			table.insert(bits, insert_i, true)
		end
		n = math.floor(n/2)
	end
	return bits
end



function update()
	-- read address from redstone dots
	local addr = bits_to_n(read_ystack(-2, config.addr_bit_count, unpack(config.addr_pos)), true)

	-- write value from din to memory, if enabled
	if config.enable_write and read_trapdoor_east(unpack(config.write_enable_pos)) then
		memory[addr] = bits_to_n(read_ystack(-2, config.data_bit_count, unpack(config.din_pos)), true)
		print(("  Write to:  0x%.8x -> 0x%.8x"):format(addr, memory[addr]))
	else
		print(("  Read from: 0x%.8x -> 0x%.8x"):format(addr, memory[addr]))
	end

	-- write current RAM read value to dout
	write_ystack(-2, n_to_bits(memory[addr], config.data_bit_count, true), unpack(config.dout_pos))
end

-- main loop:
-- wait for a clock signal,
-- read address, do read, write if enabled and write signal high
while true do
	print("Waiting for clock...")
	-- wait for a clock signal(also leaves the game in a tick-frozen state)
	wait_for_clock(unpack(config.clock_pos))

	--- update the memory state(perform read/write)
	update()

	-- re-start the game again(frozen by wait_for_clock)
	unfreeze()

	print()
end
