-- RECIEVER
local subscription = Communication.SubscribeToTopic("Message", 1, function(messageData) -- Subscribe to the message to be sent on port 1
    -- do some stuff idk
    return "Something", "Here's the data I want to send back to you"
end)

task.wait(10)
subscription:Unbind() -- Unsubscribe after 10 seconds
