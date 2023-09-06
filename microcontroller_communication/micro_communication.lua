local Communication = {_Threads = {}, _Ports = {}}

function Communication.SendMessage(topicName: string, port, dataToSend)
	local disk = GetPartFromPort(port, "Disk")
	
	if not disk then
		error(("[Communication.SendMessage]: A disk on port '%s' is required to send a message."):format(port or "[NONE PROVIDED]"))
	end
	
	if not dataToSend then
		dataToSend = true
	end

	local returnTable = {}

	disk:Write(topicName, dataToSend) -- it HAS to send some data!!!
	disk:Write(`{topicName}_Returns`, returnTable)

	TriggerPort(port)

	if Communication._Threads[topicName] then
		coroutine.close(Communication._Threads[topicName])
	end

	Communication._Threads[topicName] = task.delay(1, function()
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
		error("[Communication.SubscribeToTopic]: Port not found or not provided")
	end

	if not Communication._Ports[port.GUID] then
		local info = {Event = nil, Subscribed = {}}
		Communication._Ports[port.GUID] = info

		info.Event = port:Connect("Triggered", function(senderPort)
			local disk = GetPartFromPort(senderPort, "Disk")

			if not disk then
				return
			end

			for _, subscription in ipairs(info.Subscribed) do
				local topicInfo = disk:Read(subscription.TopicName)

				if not topicInfo then
					continue
				end

				local returnsTable = `{topicName}_Returns`

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
					disk:Read(returnsTable)[dataIndex] = returned
				else
					table.insert(returnsTable, returned)
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
		local portTable = Communication._Ports[port.GUID]
		local index = table.find(portTable, self)

		if not index or not self._Binded then
			error("[Communication.TopicSubscription]: Topic is already unsubscribed from")
		end

		table.remove(portTable.Subscribed, index)
		self._Binded = false

		if #portTable.Subscribed == 0 then -- Remove the table if there's no more subscriptions
			portTable.Event:Unbind()
			portTable.Event = nil

			Communication._Ports[port.GUID] = nil
		end

		print(("[Communication.TopicSubscription]: Unsubscribed from topic: '%s'"):format(topicName))
	end

	function self:SendReturnMessage(topicName: string, data)
		if not self._DiskPort then
			print("[Communication.TopicSubscription]: At least one message must be recieved to be returned to")
			return
		end

		return Communication.SendMessage(topicName, self._DiskPort, data)
	end

	table.insert(Communication._Ports[port.GUID].Subscribed, self)
	return self
end

function Communication.ScrambleAntennaID(port)
	if typeof(port) == "number" then
		port = GetPort(port)
	end

	local antenna = GetPartFromPort(port, "Antenna") or error("[Communication.ScrambleAntennaID]: No antenna found on the provided port")
	local newID = math.random(1, 999)

	local messageResult = Communication.SendMessage("_ScrambleAntenna", port, newID)
	task.wait(0.5)
	
	if #messageResult.Results > 0 then -- 
		antenna:Configure({AntennaID = newID})
	else
		print("[Communication.ScrambleAntennaID]: No returns, antenna ID not changed")
	end
	
	return messageResult
end

function Communication.SubscribeToAntennaScramble(port)
	if typeof(port) == "number" then
		port = GetPort(port)
	end

	local antenna = GetPartFromPort(port, "Antenna") or error("[Communication.ScrambleAntennaID]: No antenna found on the provided port")
	local subscription = Communication.SubscribeToTopic("_ScrambleAntenna", port, function(newID)
		antenna:Configure({AntennaID = newID})
		return true
	end)

	return subscription
end

export type MessageResult = typeof(Communication.SendMessage())
export type TopicSubscription = typeof(Communication.SubscribeToTopic())

return Communication
