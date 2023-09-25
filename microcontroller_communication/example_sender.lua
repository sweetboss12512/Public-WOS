-- SENDER
local messageResult = Communication.SendMessage("Message", 1, "Hello!") -- Send the message on port 1

local something = messageResult:WaitForResult("Something", 5) -- Maximum of 5 seconds for the reciever to return a result with that index
local allResults = messageResult.Results

print("Something: "..something)
print("All results:")
print(JSONEncode(allResults))
