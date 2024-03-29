-- Objects
local Keyboard = GetPartFromPort(1, "Keyboard")
local ResultsSign = GetPartFromPort(1, "Sign")
local Screen = GetPartFromPort(1, "Screen")
local Disk = GetPartFromPort(2, "Disk")
local TriggerAntenna = GetPartFromPort(2, "Antenna")

-- Screen Objects
Screen:ClearElements()

local background = Screen:CreateElement("Frame", { BackgroundColor3 = Color3.fromHex("#3C3C3C"), Size = UDim2.fromScale(1, 1) })
local mainTitle = Screen:CreateElement("TextLabel", { RichText = true, Text = "«« <u>Registered Turrets</u> »»", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.1), Font = Enum.Font.Code })
local bottomFrame = Screen:CreateElement("Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#323232"), BorderSizePixel = 0, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.1) })
local turretListFrame = Screen:CreateElement("ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.Y, BottomImage = "", TopImage = "", AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromHex("#65BC3C"), BackgroundTransparency = 0.85, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.5), Selectable = false, Size = UDim2.fromScale(1, 0.8), SelectionGroup = false, ClipsDescendants = true })

local TurretButtonTemplate = { Text = "Defense #1", TextColor3 = Color3.fromHex("#000000"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#FFFFFF"), BorderColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.9, 0.1), Font = Enum.Font.Code, RichText = true}

background:AddChild(mainTitle)
background:AddChild(bottomFrame)
background:AddChild(turretListFrame)

-- Tables
local Commands = {}
local CommandNames = {}
local Settings = Disk:Read("Settings")

local UnremoveableCommanders = {
	"sweetboss151"
}

local Turrets = {
	["Defense"] = {}, -- Turret configuration starts with AllExcept
	["Miner"] = {}, -- Turret configuration starts with Radar, and when it updates any mining lasers if has if it has any.
	["Mouse"] = {}, -- this is just for ar controllers, which arent in stable yet. type does not work yet
	["Predict"] = {} -- Predicting turrets.
}
local TurretColors = { -- Colors of the turrets
	["Defense"] = BrickColor.new("Persimmon").Color,
	["Miner"] = BrickColor.new("Bright blue").Color,
	["Mouse"] = BrickColor.new("Bright orange").Color,
	["Predict"] = BrickColor.new("Burlap").Color,
}

-- Modules
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
		if senderPort.GUID == port.GUID then
			print("it was sent by myself...")
			return
		end

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

-- Items
local TurretListLayout = nil -- Pseudo list layout.

-- Variables
local selectedTurret = nil
local inCommand = false

local TurretFunctions = {}
local RegisterQueue = {}

-- Variables
local inCommand = false

-- Functions
local function NewListLayout(parent, padding: UDim, startUdim: UDim, centerObjects: boolean, fillDirecton)
	startUdim = startUdim or UDim.new()
	fillDirecton = fillDirecton or Enum.FillDirection.Horizontal

	local self =  {}
	self.Parent = parent
	self.Children = {}
	self.FillDirection = fillDirecton

	function self:AddChild(screenObject)
		local position

		-- ITS UGLY, BUT IT WORKS NOT GOING TO CHANGE UNTIL IT'S A PROBLEM.
		if fillDirecton == Enum.FillDirection.Vertical then
			position = UDim2.new(0, 0, startUdim.Scale, startUdim.Offset)

			local latestChild = self.Children[#self.Children]

			if latestChild then
				local yScale = latestChild.Position.Y.Scale + latestChild.Size.Y.Scale
				local yOffset = latestChild.Position.Y.Offset + latestChild.Size.Y.Offset

				position = UDim2.new(0, 0, yScale + padding.Scale, yOffset + padding.Offset)
			end


			if centerObjects then
				screenObject.AnchorPoint = Vector2.new(0.5, screenObject.AnchorPoint.Y)
				position += UDim2.fromScale(0.5, 0)
			end

		elseif fillDirecton == Enum.FillDirection.Horizontal then
			position = UDim2.new(startUdim.Scale, startUdim.Offset, 0, 0)

			local latestChild = self.Children[#self.Children]

			if latestChild then
				local xScale = latestChild.Position.X.Scale + latestChild.Size.X.Scale
				local xOffset = latestChild.Position.X.Offset + latestChild.Size.X.Offset

				position = UDim2.new(xScale + padding.Scale, xOffset + padding.Offset, 0, 0)
			end
		end

		screenObject.Position = position
		self.Parent:AddChild(screenObject)
		table.insert(self.Children, screenObject)
	end

	function self:Refresh()
		local clone = table.clone(self.Children)
		self.Children = {}

		for _, v in ipairs(clone) do
			self:AddChild(v)
		end

		clone = nil
	end

	function self:Remove(child)
		local index = child

		if typeof(child) ~= "number" then
			index = table.find(self.Children, child)
		end

		if index then
			print("Found and removing child.")
			table.remove(self.Children, index)
			self:Refresh()
		else
			print("Child was not found.")
		end
	end

	return self
end

local function CountKeys(tble) -- because #table only works on arrays
	local length = 0
	
	for _ in pairs(tble) do
		length += 1
	end
	
	return length
end

local function SetResults(text, textTime, pauseThread: boolean)
	ResultsSign:Configure({SignText = text})

	if textTime then
		if pauseThread then
			task.wait(textTime)
			ResultsSign:Configure({Text = "..."})
		else
			task.delay(textTime, function()
				ResultsSign:Configure({SignText = "..."})
			end)
		end
	end
end

local function UpdateTurretDiskSaves(turret) -- this lets you configure the turrets and have it save without changing their register info
	Disk:Write(turret.Name, {
		Min = turret.Min,
		Max = turret.Max,
		Target = turret.Target,
		Enabled = turret.Enabled,
		Color = turret.Color,
	})
end

local function UpdateTurrets()
	local su, er = pcall(function()
		for _, turretType in pairs(Turrets) do

			for _, turret in pairs(turretType) do
				if turret.Target then

					if turret.Target:match("^%s*$") then
						turret.Target = nil
					end
				end

				local info = TurretFunctions[turret.Type]

				if not info then
					continue
				end

				if turret.Enabled then
					turret.Label.Text = turret.Name
				else
					turret.Label.Text = ("<s>  %s  </s>"):format(turret.Name)
					turret.Gyro:Configure({Seek = "Turret Disabled"})
					continue
				end

				if info.Update then
					info.Update(turret)
				end

				UpdateTurretDiskSaves(turret)
			end
		end
	end)
	
	if not su then
		print(er)
	end
end

local function TurretScreenInfo(turret)
	TurretButtonTemplate.Text = turret.Name
	TurretButtonTemplate.BackgroundColor3 = turret.Color or TurretColors[turret.Type] or Color3.fromRGB(40, 40, 40)
	
	local turretInfo = Screen:CreateElement("TextButton", TurretButtonTemplate)

	TurretListLayout:AddChild(turretInfo)

	turretInfo.MouseButton1Click:Connect(function()
		if selectedTurret then
			selectedTurret.Button.BorderSizePixel = 0
			
			if selectedTurret.Button == turretInfo then
				selectedTurret = nil
				return
			end
		end
		
		turretInfo.BorderSizePixel = 4
		selectedTurret = {Button = turretInfo, Turret = turret}
	end)
	
	return turretInfo
end

local function RepeatedTurretNames(name)
	local count = 0

	for _, turretType in pairs(Turrets) do

		for index in pairs(turretType) do

			if index == name then
				count += 1
			end
		end
	end

	return count
end

local function GetWhitelisted()
	local list = {}
	
	for _, v in ipairs(UnremoveableCommanders) do
		if not table.find(list, v) then
			table.insert(list, v)
		end
	end
	
	for _, v in ipairs(Settings.Users) do
		if not table.find(list, v) then
			table.insert(list, v)
		end
	end
	
	for _, v in ipairs(Settings.Whitelist) do
		if not table.find(list, v) then
			table.insert(list, v)
		end
	end
	
	return list
end

local function RegisterTurret(info)
	local success, er = pcall(function()
		print("NAME")
		print(info.Name)
		
		if not info.Name then
			print("NO NAME")
			info.Name = info.Type..CountKeys(Turrets[info.Type]) + 1
		end
		
		--local repeated = info.Name
		--local count = 1
		--print("hiii")
		--print(CountKeys(Turrets[info.Type]))
		
		--while Turrets[info.Type][repeated] do
		--	repeated = info.Name..count
		--	count += 1
		--end
		
		--if count > 1 then
		--	info.Name = repeated
		--end
		
		if RepeatedTurretNames(info.Name) > 0 then
			info.Name..= RepeatedTurretNames(info.Name) + 1
		end
		
		for _, turretType in pairs(Turrets) do
			
			for index, turret in pairs(turretType) do
				
				if turret.Gyro.GUID == info.Parts.Gyro.GUID then
					print(index.." tried to register twice")
					SetResults(index.." tried to register twice", 2)
					return
				end
			end
		end
		
		--print("Registering turret")
		local oldConfiguration = Disk:Read(info.Name) or {}
		local turret = {}

		turret.Name = info.Name -- so you can have mega turret, main turret, blah blah blah
		turret.Type = info.Type or error(info.Name.." does not have a valid turret type.")
		turret.Min = oldConfiguration.Min or info.Min or 50
		turret.Max = oldConfiguration.Max or info.Max or 820
		turret.Target = oldConfiguration.Target or nil
		turret.Enabled = oldConfiguration.Enabled or true
		turret.Color = info.Color
		turret.Label = TurretScreenInfo(turret)

		-- Parts
		for partName, id in pairs(info.Parts) do
			
			if turret[partName] then
				error("[REGISTER TURRET]: Cannot overwrite turret index: "..tostring(id))
			else
				turret[partName] = id
			end
		end
		
		
		if TurretFunctions[info.Type].Init then
			TurretFunctions[info.Type].Init(turret, info.Parts)
		end

		turret.Gyro:Configure({MaxTorque = info.Torque or Vector3.new(3000, 0, 3000)})
		Turrets[turret.Type][turret.Name] = turret
	end)
	
	if not success then
		print(er)
	end
	
end

-- Prediction
local function CalculateVelocity(before, after, deltaTime) -- Turret prediction
	local displacement = (before - after)
	local velocity = displacement / deltaTime

	return velocity
end

-- Setup
TurretListLayout = NewListLayout(turretListFrame, UDim.new(0.05, 0), UDim.new(0.05, 0), true, Enum.FillDirection.Vertical)

if not Settings then
	Disk:Write("Settings", {
		Whitelist = {},
		Users = {"sweetboss151"},
		Threads = {},
		AutoInit = false -- Whether the controller attempts to init on startup.
	})

	Settings = Disk:Read("Settings")
end

-- Put every command name in the dict.

Keyboard:Connect("TextInputted", function(text, playerName)
	if not (table.find(UnremoveableCommanders, playerName) or table.find(Settings.Users, playerName) or playerName == "sweetboss151") then
		SetResults("Access denied", 1.5)
		return
	end
	
	if inCommand then
		return
	end
	
	text = text:gsub("\n", "")
	local arguments = {}

	for value in string.gmatch(text, "%S+") do
		table.insert(arguments, value);
	end

	local commandName = arguments[1]:lower()
	table.remove(arguments, 1)

	print("ARGUMENTS")
	print(JSONEncode(arguments))

	local command = CommandNames[commandName]
	
	if not command then
		SetResults("Command not found. '"..commandName.."'", 2)
		return
	end
	
	if command.NeedSelected and not selectedTurret then
		SetResults("No turret selected")
		return
	end
	
	--inCommand = true
	
	local success, returned = pcall(function()
		return command.Callback(arguments)
	end)
	
	if success then
		SetResults(returned, 3)
	else
		SetResults("There was an error")
		print(returned)
	end

	inCommand = false
end)

SetResults("Turret controller activated")

-- Commands
Commands.Min = {
	Usages = {"turretmin", "tmin"},
	NeedSelected = true,
	Callback = function(args)
		local newValue = tonumber(args[1])
		
		if not newValue then
			return "Invalid value"
		end
		
		selectedTurret.Turret.Min = newValue
		UpdateTurrets()
		return ("Set min to %d"):format(newValue)
	end,
}

Commands.Max = {
	Usages = {"turretman", "tmax"},
	NeedSelected = true,
	Callback = function(args)
		local newValue = tonumber(args[1])

		if not newValue then
			return "Invalid value"
		end

		selectedTurret.Turret.Max = newValue
		UpdateTurrets()
		return ("Set max to %d"):format(newValue)
	end,
}

Commands.Seek = {
	NeedSelected = true,
	Callback = function(args)
		local seek = table.concat(args, " ")
		
		if seek:match("^%s$+") then
			return "No seek provided"
		end
		
		selectedTurret.Turret.Gyro:Configure({Seek = seek})
		return "Seeking '"..seek.."'"
	end,
}

Commands.Init = {
	Usages = {"start"},
	Callback = function()
		Communication.SendMessage("InitTurrets", 2, RegisterTurret)
		return "Turrets initiated"
	end,
}

Commands.Target = {
	NeedSelected = true,
	Callback = function(args)
		local newTarget = args[1] or ""
		
		if newTarget:match("^%s*$") then
			newTarget = nil
			selectedTurret.Turret.Target = nil
			return "Set target to none"
		end
		
		selectedTurret.Turret.Target = newTarget
		
		UpdateTurrets()
		return "Targetting "..newTarget
	end,
}

Commands.AllTarget = {
	Callback = function(args)
		local newTarget = args[1] or ""

		if newTarget:match("^%s*$") then
			newTarget = nil
		end
		
		for _, turretType in pairs(Turrets) do

			for _, turret in pairs(turretType) do
				turret.Target = newTarget
			end
		end
		
		UpdateTurrets()
		
		if not newTarget then
			return "All targetting None"
		end
		
		return "All targetting "..newTarget
	end,
}

Commands.Update = {
	Callback = function()
		UpdateTurrets()
		return "Updated turrets"
	end,
}

Commands.Enable = {
	Usages = {"activate", "on"},
	NeedSelected = true,
	Callback = function()
		selectedTurret.Turret.Enabled = true
		
		UpdateTurrets()
		return "Enabled selected turret"
	end,
}

Commands.Disable = {
	Usages = {"deactivate", "off"},
	NeedSelected = true,
	Callback = function()
		selectedTurret.Turret.Enabled = false
		
		UpdateTurrets()
		return "Disabled selected turret"
	end,
}

Commands.EnableAll = {
	Usages = {"eall", "activateall", "onall"},
	Callback = function()
		
		for _, turretType in pairs(Turrets) do

			for _, turret in pairs(turretType) do
				turret.Enabled = true
			end
		end
		
		UpdateTurrets()
		return "All turrets enabled"
	end,
}

Commands.DisableAll = {
	Usages = {"deall", "deactivateall", "offall"},
	Callback = function()

		for _, turretType in pairs(Turrets) do

			for _, turret in pairs(turretType) do
				turret.Enabled = false
			end
		end
		
		UpdateTurrets()
		return "All turrets disabled"
	end,
}

Commands.Setting = {
	NeedSelected = true,
	Usages = {"s"},
	Callback = function(args)
		local name = args[1] or ""
		
		if name:lower() == "target" and not selectedTurret.Turret.Target then
			return "None"
		end
		
		for settingName, value in pairs(selectedTurret.Turret) do
			
			if name:lower() == settingName:lower() then
				
				if not tostring(value) then
					return "Cannot display that setting."
				end
				
				return tostring(value)
			end
		end
		
		return "Setting '"..name.."' not found"
	end,
}

Commands.Scramble = { -- Sets the antenna id to something random.
	Usages = {"scram", "encrypt", "enc"},
	Callback = function()
		local randInt = math.random(1, 999)

		for _, turretType in pairs(Turrets) do

			for _, turret in pairs(turretType) do
				if not turret.InitAntenna then
					continue
				end

				turret.InitAntenna:Configure({AntennaID = randInt})
			end
		end

		TriggerAntenna:Configure({AntennaID = randInt})
		return ("Trigger antenna ID is now %d"):format(randInt)
	end,
}

Commands.AddUser = {
	Usages = {"addu"},
	Callback = function(args)
		local user = args[1]
		
		for _, v in ipairs(Settings.Users) do
			if user == v then
				return user.." is already a commander"
			end
		end
		
		table.insert(Settings.Users, user)
		return "Added "..user.." as a commander"
	end,
}

Commands.RemoveUser = {
	Usages = {"removeu"},
	Callback = function(args)
		local user = args[1]
		
		for i, userName in ipairs(Settings.Users) do
			
			if user == userName:sub(1, #user) then
				table.remove(Settings.Users, i)
				return "Removed "..userName.." as a commander"
			end
		end
		
		return user.." was not found."
	end,
}

Commands.AddWhitelist = {
	Usages = {"addw"},
	Callback = function(args)
		local user = args[1]

		for _, v in ipairs(Settings.Whitelist) do
			if user == v then
				return user.." is already whitelisted"
			end
		end

		table.insert(Settings.Whitelist, user)
		return "Added "..user.." to the whitelist"
	end,
}

Commands.RemoveWhitelist = {
	Usages = {"removew"},
	Callback = function(args)
		local user = args[1]

		for i, userName in ipairs(Settings.Whitelist) do

			if user == userName:sub(1, #user) then
				table.remove(Settings.Whitelist, i)
				return "Removed "..userName.." as whitelisted"
			end
		end

		return user.." was not found."
	end,
}

Commands.ListWhitelist = {
	Usages = {"listw"},
	Callback = function(args)
		
		for _, v in ipairs(Settings.Whitelist) do
			SetResults(v, 0.7, true)
		end
	end,
}

Commands.ListUsers = {
	Callback = function(args)
		for _, v in ipairs(Settings.Users) do
			SetResults(v, 0.7, true)
		end
	end,
}

Commands.ListCommands = {
	Usages = {"cmds", "listcmds"},
	Callback = function(args)
		
		for mainName, info in pairs(Commands) do
			SetResults(mainName, 0.7, true)
			
			if info.Usages then
				SetResults("Aliases: "..table.concat(info.Usages, " | "), 1.5, true)
			end
		end
		
		return "..."
	end,
}

Commands.AutoInit = {
	Callback = function()
		Settings.AutoInit = not Settings.AutoInit
		SetResults("Set auto init to "..tostring(Settings.AutoInit), 2, true)
		return tostring(Settings.AutoInit)
	end,
}

for mainName, command in pairs(Commands) do
	CommandNames[mainName:lower()] = command

	if not command.Usages then
		continue
	end

	for _, usage in pairs(command.Usages) do
		CommandNames[usage:lower()] = command
	end
end

-- Turret Functions
TurretFunctions.Defense = {
	Update = function(turret)
		local seek = ("AllExcept %s"):format(table.concat(GetWhitelisted(), " "))
		
		if turret.Target then
			print("I have a target")
			seek = "Radar " -- this is because idk how to make radar work with allexcept (if it even does)
			seek = seek..turret.Target
		end

		seek = ("%s Min%d Max%d"):format(seek, turret.Min, turret.Max) -- seek.." Min"..turret.Min.." Max"..turret.Max
		turret.Gyro:Configure({Seek = seek})
	end,
}

TurretFunctions.Miner = {
	Update = function(turret)
		local seek = "Radar "

		if turret.Target then
			seek = seek..turret.Target
		end

		if turret.MiningLasers then
			for _, miningLaser in ipairs(turret.MiningLasers) do
				miningLaser:Configure({MaterialToExtract = turret.Target})
			end
		end

		seek = seek.." Min"..turret.Min
		turret.Gyro:Configure({Seek = seek})
	end,
}

TurretFunctions.Predict = {
	Update = function(turret)
		if Settings.Threads[turret] then
			coroutine.close(Settings.Threads[turret])
			Settings.Threads[turret] = nil
		end
		
		if not turret.Enabled then
			return
		end
		
		Settings.Threads[turret] = task.spawn(function()
			while true do
				if not turret.Enabled then
					coroutine.close(turret.MainThread)
					turret.MainThread = nil
					print("I'm disabled")
					break
				end
				
				local closestPlayer = nil
				local playerPosition1 = nil
				local turretPosition = if turret.Instrument then turret.Instrument:GetReading(6) else turret.Gyro.CFrame.Position
				
				-- ^ turret.Gyro.CFrame DOES NOT UPDATE IF IT MOVES!!!

				local currentTarget = turret.Target

				if not currentTarget then
					local distance = math.huge
					local whitelisted = GetWhitelisted()

					for playerName, position in pairs(turret.LifeSensor:GetReading()) do

						if table.find(whitelisted, playerName) then
							continue
						end

						local distanceFromPlayer = (turretPosition - position).Magnitude

						if distanceFromPlayer > turret.Max or distanceFromPlayer < turret.Min then
							continue
						end

						if distanceFromPlayer < distance then
							currentTarget = playerName
							playerPosition1 = position
							distance = distanceFromPlayer
						end
					end
				end

				playerPosition1 = turret.LifeSensor:GetReading()[currentTarget]

				if not playerPosition1 then
					task.wait(1)
					continue
				end

				if not currentTarget then
					print("No current target")
					task.wait(1)
					continue
				end

				local distanceFromTurret = (turretPosition - playerPosition1).Magnitude

				if distanceFromTurret < turret.Min or distanceFromTurret > turret.Max then
					print("out of range")
					task.wait(1)
					continue
				end

				local deltaTime = task.wait()
				local playerPosition2 = turret.LifeSensor:GetReading()[currentTarget]

				if not playerPosition2 then
					task.wait(1)
					continue
				end

				local playerVelocity = CalculateVelocity(playerPosition1, playerPosition2, deltaTime) -- vector3
				turret.Gyro:PointAt(playerPosition2 - (playerVelocity / 2))
				TriggerPort(turret.Gyro)
			end
		end)
	end,
}

for i, thread in pairs(Settings.Threads) do
	print("Closing thread")
	coroutine.close(thread)
	Settings.Threads[i] = nil
end

-- AUTO INIT
if Settings.AutoInit then
	task.wait(0.5)
	Communication.SendMessage("InitTurrets", 2, RegisterTurret)
	task.wait(16 / 10)
	UpdateTurrets()
	SetResults("Auto initated turrets", 3)
end
