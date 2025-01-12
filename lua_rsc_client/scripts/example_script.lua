-- this is an example Lua RSC script.
math.randomseed(os.time())

print("setting blocks")
for i=1, 10 do
	set_block(535, i,i,i)
end

print("getting block")
local id = get_block(0,0,0)
print("id",id)

print("observing block...")
local new_id = observe_block(10,11,10) -- game is frozen after observe
print("(now tick frozen) observed block changed to:", new_id)

print("setting response blocks")
for i=2, 8, 2 do
	local b = (math.random()>0.5) and 9223 or 0
	set_block(b, 0,i,2)
end

print("unfreezing game")
unfreeze()
