-- TURRET CONFIG
local TurretInfo = {
	Name = nil, -- Name of the turret
	Type = "Defense", -- Turret type. if set to nil, it will be changed to miner.
	Min = 10, -- Gyro min
	Max = 810, -- Gyro max,
	Torque = Vector3.new(3000, 0, 3000), -- Vector3, the max torque of the turret's gyro.
	Color = Color3.fromRGB(200, 255, 100), -- Color3.new() -- Color override of the turret's label.
	
	-- Port numbers for each part of the turret.
	Parts = {
		Gyro = 1,
		InitAntenna = 2, -- The antenna that the controller triggers to initalize the turret.
		
		-- Extra parts for predicting turrets
		LifeSensor = 3,
		Instrument = 3,
	}
}


-- CODE
local Communication = {_Threads = {}}

function Communication.SendMessage(topicName, port, info)
	local disk = GetPartFromPort(port, "Disk")
	disk:Write(topicName, info)

	TriggerPort(port)

	if Communication._Threads[topicName] then
		coroutine.close(Communication._Threads[topicName])
	end

	Communication._Threads[topicName] = task.delay(1, function()
		disk:Write(topicName, nil)
	end)
end

function Communication.SubscribeToTopic(topicName, port, callback)
	local newInfo = {
		_Event = nil,
		_DiskPort = nil,
		TopicName = topicName
	}

	if typeof(port) == "number" then
		port = GetPort(port)
	end

	newInfo._Event = port:Connect("Triggered", function(senderPort)
		local disk = GetPartFromPort(senderPort, "Disk")

		if not disk then
			print("[Communication.SubscribeToTopic]: Port that triggered subscription did not have a disk.")
			print(JSONEncode(newInfo))
			return
		end

		local topicInfo = disk:Read(topicName)

		if topicInfo then
			newInfo._Event = senderPort
			local returned = callback(topicInfo)

			if not returned then
				return
			end

			Communication.SendMessage(topicName.."Return", senderPort, returned)
		else
			print("[Communication.SubscribeToTopic]: Topic was fired, but no information was sent.")
		end
	end)

	return newInfo
end

function Communication.UnsubscribeToTopic(topicInfo)
	if topicInfo.UnSubscribed then
		error("[Communication.UnsubscribeToTopic]: Topic is already unsubscribed from.")
	end
	
	topicInfo._Event:Unbind()
	topicInfo.UnSubscribed = true
	print("[Communication.UnsubscribeToTopic]: Unsubscribed from "..topicInfo.TopicName)
end

-- Set the gyro torque even when it's not initiated, so it won't fling.
local gyro = GetPartFromPort(TurretInfo.Parts.Gyro, "Gyro")

if gyro then
	gyro:Configure({MaxTorque = TurretInfo.Torque or Vector3.new(3000, 0, 3000)})
end

for name, id in pairs(TurretInfo.Parts) do
	TurretInfo.Parts[name] = GetPartFromPort(id, if name ~= "InitAntenna" then name else "Antenna")
end


Communication.SubscribeToTopic("InitTurrets", 2, function(registerFunc)
	task.wait(math.random(1, 15) / 100)
	registerFunc(TurretInfo)
end)
