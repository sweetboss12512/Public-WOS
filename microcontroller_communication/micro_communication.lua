local Communication = {_Threads = {}, _Ports = {}}

function Communication.SendMessage(topicName: string, port, dataToSend)
	local disk = GetPartFromPort(port, "Disk")

	if not disk then
		error(("[Communication.SendMessage]: A disk on port '%s' is required to send a message."):format(port or "[NONE PROVIDED]"))
	end

	local returnTable = {}
	
	disk:Write(topicName, dataToSend)
	disk:Write(topicName.."Returns", returnTable)

	TriggerPort(port)

	if Communication._Threads[topicName] then
		coroutine.close(Communication._Threads[topicName])
	end

	Communication._Threads[topicName] = task.delay(1, function() -- Idk about this...
		disk:Write(topicName, nil)
	end)

	local self = {
		Results = returnTable
	}

	function self:WaitForResult(index, timeoutSeconds)
		local data
		local timeWaited = 0
		timeoutSeconds = timeoutSeconds or 10
		
		while not data and timeWaited <= timeoutSeconds do
			timeWaited += task.wait()
			data = returnTable[index]
		end

		if not data then
			print("[Communication.MessageResult]: Yield timeout, failed to get data results")
			--error("[Communication.MessageResult]: Yield timeout, failed to get data results")
		end

		return data
	end

	return self
end

function Communication.SubscribeToTopic(topicName: string, port, callback)

	if typeof(port) == "number" then
		port = GetPort(port)
	end

	if not port then
		error(("[Communication.SubscribeToTopic]: Port not found, id: %s"):format(port or "none provided"))
	end

	if not Communication._Ports[port.GUID] then
		Communication._Ports[port.GUID] = {}

		port:Connect("Triggered", function(senderPort)

			local disk = GetPartFromPort(senderPort, "Disk")

			if not disk then
				return
			end

			for _, subscription in ipairs(Communication._Ports[port.GUID]) do
				local topicInfo = disk:Read(subscription.TopicName)

				if not topicInfo then
					continue
				end

				subscription._DiskPort = senderPort
				local success, dataIndex, returned = pcall(subscription._Callback, topicInfo)

				if not success then
					print("[Communication.TopicSubscription]: Error in callback:\n"..dataIndex) 
					continue
				end

				if not dataIndex then
					continue
				end

				if returned then
					disk:Read(subscription.TopicName.."Returns")[dataIndex] = returned
				else
					table.insert(disk:Read(subscription.TopicName.."Returns"), returned)
				end
			end
		end)
	end

	local self = {
		_DiskPort = nil,
		_Binded = true,
		_Callback = callback,
		TopicName = topicName,
	}

	function self:Unbind()
		local index = table.find(Communication._Ports[port.GUID], self)

		if not index or not self._Binded then
			error("[Communication.TopicSubscription]: Topic is already unsubscribed from")
		end

		table.remove(Communication._Ports[port.GUID], index)
		self._Binded = false
		print(("[Communication.TopicSubscription]: Unsubscribed from topic: '%s'"):format(topicName))
	end

	function self:SendReturnMessage(topicName: string, data)
		if not self._DiskPort then
			print("[Communication.TopicSubscription]: At least one message must be recieved to be returned to")
			return
		end

		return Communication.SendMessage(topicName, self._DiskPort, data)
	end

	table.insert(Communication._Ports[port.GUID], self)
	return self
end

function Communication:ScrambleAntennaID(port)
	if typeof(port) == "number" then
		port = GetPort(port)
	end

	local antenna = GetPartFromPort(port, "Antenna") or error("[Communication:ScrambleAntennaID]: No antenna found on the provided port")
	local newID = math.random(1, 999)

	local messageResult = Communication.SendMessage("_ScrambleAntenna", port, newID)
	task.wait(1)
	antenna:Configure({AntennaID = newID})
	return messageResult
end

function Communication:SubscribeToAntennaScramble(port)
	if typeof(port) == "number" then
		port = GetPort(port)
	end

	local antenna = GetPartFromPort(port, "Antenna") or error("[Communication:ScrambleAntennaID]: No antenna found on the provided port")
	local subscription = Communication.SubscribeToTopic("_ScrambleAntenna", port, function(newID)
		antenna:Configure({AntennaID = newID})
	end)

	return subscription
end

return Communication
