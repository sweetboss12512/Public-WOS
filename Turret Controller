-- Objects
local Keyboard = GetPartFromPort(1, "Keyboard")
local Disk = GetPartFromPort(2, "Disk")
local ResultsSign = GetPartFromPort(1, "Sign")
local Screen = GetPartFromPort(1, "Screen")

Screen:ClearElements()
task.wait(1)
local MainFrame = Screen:CreateElement("ScrollingFrame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(150, 150, 150),
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromScale(0, 5)
})

-- Tables
local Commands = {}
local Settings = Disk:Read("Settings")
local Commanders = {
	"sweetboss151"
}
local UnremoveAbleWhitelisted = {
	"sweetboss151"
}
local Turrets = {
	["Defense"] = {}, -- Turret configuration starts with AllExcept
	["Miner"] = {}, -- Turret configuration starts with Radar, and when it updates any mining lasers if has if it has any.
	["Mouse"] = {} -- this is just for ar controllers, which arent in stable yet. type does not work yet
}
local TurretColors = {
	["Defense"] = BrickColor.new("Grime").Color,
	["Miner"] = BrickColor.new("Bright blue").Color,
	["Mouse"] = BrickColor.new("Bright orange").Color
}

local TurretInitFunctions = {
	["Miner"] = function(newTurret, parts)
		newTurret.MiningLasers = parts.MiningLasers
	end,
}

-- Variables
local infoOffset = 0
local selectedTurret = nil
local inCommand = false

local TurretUpdateFunctions = {
	["Defense"] = function(turret)
		local seek = ""
		
		seek = seek.." AllExcept "
		
		for _, whitelisted in pairs(Settings.Whitelisted) do
			seek = seek..whitelisted.." "
		end
		for _, whitelisted in pairs(UnremoveAbleWhitelisted) do
			seek = seek..whitelisted.." "
		end
		
		if turret.Target ~= "" and turret.Target ~= nil and turret.Target ~= " " then
			seek = "Radar " -- this is because idk how to make radar work with allexcept (if it even does)
			seek = seek..turret.Target
		end
		
		seek = seek.." Min"..turret.Min.." Max"..turret.Max
		turret.Gyro:Configure({Seek = seek})
	end,
	
	["Miner"] = function(turret)
		turret.Gyro:Configure({Seek = "Radar "..turret.Target})
		
		if turret.MiningLasers then
			for _, miningLaser in ipairs(turret.MiningLasers) do
				miningLaser:Configure({MaterialToExtract = turret.Target})
			end
		end
	end,
}

-- Variables
local inCommand = false

if not Settings then
	Disk:Write("Settings", {
		Whitelisted = {}
	})
				
	Settings = Disk:Read("Settings")
end

-- Functions
local function countKeys(tble) -- because #table only works on arrays
	local length = 0
	
	for _ in pairs(tble) do
		length += 1
	end
	
	return length
end

local function SetResults(text, textTime)
	ResultsSign:Configure({SignText = text})

	if textTime then
		task.delay(textTime, function()
			ResultsSign:Configure({SignText = "Results"})
		end)
	end
end

local function UpdateTurretDiskSaves(turret) -- this lets you configure the turrets and have it save without changing their register info
	Disk:Write(turret.Name, {
		Min = turret.Min,
		Max = turret.Max,
		Target = turret.Target
	})
end

local function UpdateTurrets()
	for _, turretType in pairs(Turrets) do
		
		for _, turret in pairs(turretType) do
			if not turret.Enabled then
				turret.Gyro:Configure({Seek = ""})
				continue
			end
			
			print("bah")
			print(turret.Min)
			print(turret.Max)
			Disk:Write(turret.Name, turret.Target)
			
			local updateFunction = TurretUpdateFunctions[turret.Type]
			
			if updateFunction then
				updateFunction(turret)
				UpdateTurretDiskSaves(turret)
			end
		end
	end
end

local function NewTurretScreenInfo(turret)
	local newTurretInfo = Screen:CreateElement("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(.8, .02),
		Position = UDim2.new(.5, 0, .01, 10),
		BorderSizePixel = 0,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundColor3 = TurretColors[turret.Type],
		Font = Enum.Font.Code,
		TextScaled = true,
		Text = turret.Name,
	})
	
	MainFrame:AddChild(newTurretInfo)
	newTurretInfo.Position += UDim2.fromScale(0, infoOffset)
	infoOffset += (newTurretInfo.Size.Y.Scale + 0.009)

	newTurretInfo.MouseButton1Click:Connect(function()
		print(turret)
		if selectedTurret then
			selectedTurret.Button.BorderSizePixel = 0
			
			if selectedTurret.Button == newTurretInfo then
				selectedTurret = nil
				return
			end
		end
		
		newTurretInfo.BorderSizePixel = 3
		
		selectedTurret = {Button = newTurretInfo, Turret = turret}
	end)
end

local function RegisterTurret(info)
	info.Name = info.Name or info.Type..countKeys(Turrets[info.Type])
	local oldConfiguration = Disk:Read(info.Name)
	
	for _, turretType in pairs(Turrets) do
		for index, turret in pairs(turretType) do
			if turret.Gyro.GUID == info.Gyro.GUID then
				print(index.." tried to register twice")
				SetResults(index.." tried to register twice", 2)
				return
			end
			
			if turret.Name == info.Name then
				print("Conflicting names: "..index)
				SetResults("Conflicting names: "..index)
				return
			end
		end
	end
	
	print("Registering turret")
	local newTurret = {}
	
	newTurret.Name = info.Name -- so you can have mega turret, main turret, blah blah blah
	newTurret.Type = info.Type or "Miner"
	newTurret.Min = info.Min or 50
	newTurret.Max = info.Max or 800
	newTurret.Target = oldConfiguration or ""
	newTurret.Enabled = true
	
	-- Parts
	newTurret.Gyro = info.Gyro
	newTurret.PowerSwitch = info.PowerSwitch
	
	if oldConfiguration then
		newTurret.Min = oldConfiguration.Min
		newTurret.Max = oldConfiguration.Max
		newTurret.Target = oldConfiguration.Target
	end
	
	if TurretInitFunctions[info.Type] then
		print("Has a init function")
		TurretInitFunctions[info.Type](newTurret, info)
	end
	
	newTurret.Gyro:Configure({Seek = ""})
	Turrets[newTurret.Type][newTurret.Name] = newTurret
	
	NewTurretScreenInfo(newTurret)
end

-- Connections
Keyboard:Connect("TextInputted", function(text, playerName)
	--[[
	if not table.find(Commanders, playerName) and not inCommand then
		SetResults("Access denied", 1.5)
		return
	end
	--]]
	
	text = text:sub(1, -2)
	
	local arguments = string.split(text, " ")
	local commandName = string.lower(arguments[1])
	print(commandName)
	
	if Commands[commandName] and not inCommand then
		print("found command")
		Commands[commandName](arguments)
	end
end)

-- Setup
SetResults("Turret controller activated")
Disk:Write("RegisterTurret", RegisterTurret)

-- Commands
function Commands.min(arguments)
	local newValue = arguments[2]
	newValue = tonumber(newValue)
	
	if newValue and selectedTurret then
		selectedTurret.Turret.Min = newValue
		SetResults("Set min to "..newValue, 2)
		UpdateTurrets()
	else
		SetResults("No turret selected or invalid value", 2)
	end
end

function Commands.max(arguments)
	local newValue = arguments[2]
	newValue = tonumber(newValue)

	if newValue and selectedTurret then
		selectedTurret.Turret.Max = newValue
		SetResults("Set max to "..newValue, 2)
		UpdateTurrets()
	else
		SetResults("No turret selected or invalid value", 2)
	end
end

function Commands.target(arguments)
	local newTarget = arguments[2]
	
	if not selectedTurret then
		SetResults("No turret selected", 2)
		return
	end
	
	local turret = selectedTurret.Turret
	
	turret.Target = newTarget
	SetResults("Set target of "..turret.Name.." to "..newTarget, 2)
	UpdateTurrets()
end

function Commands.alltarget(arguments)
	local newTarget = arguments[2]
	
	for _, turreType in pairs(Turrets) do
		for _, turret in pairs(turreType) do
			turret.Target = newTarget
		end
	end
	
	SetResults("All targeting "..newTarget, 2)
	UpdateTurrets()
end

function Commands.reportsetting(arguments)
	local settingName = arguments[2]
	local settingValue
	
	if not selectedTurret then
		SetResults("No turret selected", 2)
		return
	end
	
	for i, v in pairs(selectedTurret.Turret) do
		if string.lower(i) == string.lower(settingName) then
			settingName = i
			settingValue = v
			break
		end
	end
	
	if settingValue then
		SetResults(settingName.." is set to "..settingValue, 2)
	else
		SetResults("'"..settingName.."' is not a valid setting", 2)
	end
end

function Commands.update() -- Manually update the turret configurations
	UpdateTurrets()
	SetResults("Updated turret's configurations", 2)
end

function Commands.addwhitelisted(arguments)
	local userName = arguments[2]
	
	table.insert(Settings.Whitelisted, userName)
	SetResults("Added "..userName.." to whitelisted", 2)
	UpdateTurrets()
end

function Commands.removewhitelisted(arguments)
	local userName = arguments[2]
	
	local results
	
	for i, name in ipairs(Settings.Whitelisted) do
		local loweredName = string.lower(name)
		
		if userName == loweredName:sub(1, #userName) then
			Settings.Whitelisted[i] = nil
			
			userName = name
			results = "Removed '"..name.."'"
			break
		end
	end
	
	UpdateTurrets()
	results = results or "'"..userName.."' is not whitelisted"
	SetResults(results, 2)
end

function Commands.listwhitelisted()
	inCommand = true
	
	for _, user in ipairs(Settings.Whitelisted) do
		SetResults(user)
		task.wait(1)
	end
	
	SetResults("", 0)
	inCommand = false
end

function Commands.reportselected()
	if selectedTurret then
		SetResults(selectedTurret.Turret.Name, 2)
	else
		SetResults("No turret selected", 2)
	end
end

function Commands.enable()
	if not selectedTurret then
		return
	end
	local turret = selectedTurret.Turret
	
	turret.Enabled = true
	SetResults("Enabled turret "..turret.Name, 2)
	UpdateTurrets()
end

function Commands.disable()
	if not selectedTurret then
		return
	end

	local turret = selectedTurret.Turret

	turret.Enabled = false
	SetResults("Deactivated turret "..turret.Name, 2)
	UpdateTurrets()
end

function Commands.enableall()
	for _, turretType in pairs(Turrets) do
		for _, turret in pairs(turretType) do
			turret.Enabled = true
		end
	end
	
	SetResults("Enabled all turrets", 2)
	UpdateTurrets()
end

function Commands.disableall()
	for _, turretType in pairs(Turrets) do
		for _, turret in pairs(turretType) do
			turret.Enabled = false
		end
	end

	SetResults("Disabled all turrets", 2)
	UpdateTurrets()
end

function Commands.shutdown() -- currently breaks the turret. do not use unless it's a emergency
	if selectedTurret then
		local turret = selectedTurret.Turret
		
		if turret.PowerSwitch then
			turret.PowerSwitch:Configure({SwitchValue = false})
		else
			SetResults("No power switch found for turret '"..turret.Name.."'", 2)
		end
	end
end

function Commands.listcommands()
	inCommand = true
	
	for commandName, _ in pairs(Commands) do
		SetResults(commandName)
		task.wait(.7)
	end
	
	SetResults("", 0)
	inCommand = false
end

while task.wait(1) do
	TriggerPort(2)
end
