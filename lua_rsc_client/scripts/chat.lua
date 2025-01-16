local getch = require("lua-getch")

con:settimeout(0.1)
getch.set_nonblocking(io.stdin, true)

print("Chat ready.")
while true do
	local resp, msg = wait_for_response("ChatMessageResp", "any")
	if resp then
		print("Got chat message: ", msg)
	end
	local input_line = io.read("*l")
	if input_line == "exit" then
		disconnect()
		break
	elseif input_line then
		print("Sending chat message: ", input_line)
		send_chat_message(input_line)
	end
end

print("Bye!")
