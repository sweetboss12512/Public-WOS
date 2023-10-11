 local WOS_MODULES = {}

local oldRequire = require -- Unstable require support.
local moduleCache = {}
	
local function require(target: any): any
	if moduleCache[target] then
		return moduleCache[target]
	elseif WOS_MODULES[target] then
		local required = WOS_MODULES[target]()
		moduleCache[target] = required
		return required
	else
		local success, required = pcall(oldRequire, target)
		assert(success, `Invalid require '{target}'`)
		return required
	end
end

WOS_MODULES.InputButton = function()
	local ActiveInputs = {}
	
	local function GetKeyboardInput(Keyboard, timeoutSeconds)
		timeoutSeconds = timeoutSeconds or error("[GetKeyboardInput]: No time provided")
		local timeWaited = 0
	
		local text, playerName
	
		local connection = Keyboard:Connect("TextInputted", function(inputText, inputPlayerName)
			print("EVENT FIRED")
			text = string.gsub(inputText, "\n+$", "")
			playerName = inputPlayerName
		end)
	
		while timeWaited < timeoutSeconds and not (text and playerName) do
			timeWaited += task.wait()
		end
	
		if not text then
			print("Ran out of time!")
		end
	
		connection:Unbind()
		return text, playerName
	end
	
	return function(config: { Time: number?, Button: TextButton, Keyboard: any, InputText: string?, DefaultText: string?, Cooldown: number?}, successInput: (string, string) -> (), failInput: () -> () | string)
		local button = config.Button
		local defaultText = config.DefaultText or button.Text
	
		config.Keyboard = config.Keyboard or error("[InputButton]: No keyboard")
		
		local onCooldown = false
		
		button.MouseButton1Click:Connect(function()
			if ActiveInputs[config.Keyboard.GUID] or onCooldown then
				return
			end
			
			ActiveInputs[config.Keyboard.GUID] = true
			onCooldown = true
			
			button.Text = config.InputText or "Input Keyboard"
	
			local text, playerName = GetKeyboardInput(config.Keyboard, config.Time or 6) -- yields
			
			if defaultText then
				button.Text = defaultText
			end
	
			if text then
				local success, errormsg = pcall(successInput, text, playerName)
	
				if not success then
					print(`[InputButton]: error in success callback:\n{errormsg}`)
				end
			else
				if typeof(failInput) == "function" then
					local success, errormsg = pcall(failInput)
	
					if not success then
						print(`[InputButton]: error in failure callback:\n{errormsg}`)
					end
				elseif typeof(failInput) == "string" then
					button.Text = failInput or defaultText
				end
			end
			
			ActiveInputs[config.Keyboard.GUID] = false
			
			if config.Cooldown then
				task.wait(config.Cooldown)
			end
			
			onCooldown = false
		end)
	end
end

WOS_MODULES.StringUtility = function()
	local module = {}
	
	function module.SplitTitleCaps(str)
		str = str:gsub("(%u)", " %1")
		return str:gsub("^%s", "")
	end
	
	function module.StringToColor3RGB(str): Color3 -- 255, 200, 255
		local split = string.split(str, ",")
	
		local r = tonumber(split[1])
		local g = tonumber(split[2])
		local b = tonumber(split[3])
	
		return Color3.fromRGB(r, g, b)
	end
	
	function module.StringToVector3(str): Vector3
		local split = string.split(str, ",")
		
		local x = tonumber(split[1])
		local y = tonumber(split[2])
		local z = tonumber(split[3])
		
		if not (x and y and z) then
			return
		end
		
		return Vector3.new(x, y, z)
	end
	
	return module
end

--

-- Modules
--local OSLibrary = {
--	Screen = Screen,
--	Keyboard = Keyboard,
--	WindowHandler = reequire(game.ServerStorage.Modules.WindowHandler),
--	FileHandler = FileHandler,

--	TaskManager = {
--		MicroTask = MicroTask,
--		StopTask = StopMicroTask,
--		TaskList = MicroTasks
--	}
--}

local InputButton = require("InputButton")
local StringUtil = require("StringUtility")

-- Objects
local Screen = OSLibrary.Screen
local Keyboard = OSLibrary.Keyboard

local background = Screen:CreateElement("Frame", { BackgroundColor3 = Color3.fromHex("#282828"), BorderColor3 = Color3.fromHex("#1B2A35"), Size = UDim2.fromScale(1, 1) })
local settingsListFrame = Screen:CreateElement("ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarImageColor3 = Color3.fromHex("#000000"), ScrollBarThickness = 0, Active = true, BackgroundColor3 = Color3.fromHex("#464646"), BorderColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 2, Size = UDim2.fromScale(0.2, 1) })
local currentColorValue = Screen:CreateElement("Frame", { BackgroundColor3 = Color3.fromHex("#C80000"), BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.12), Size = UDim2.fromScale(1, 0.07) })
local currentColorTitle = Screen:CreateElement("TextButton", { Text = "Color", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.05), Size = UDim2.fromScale(1, 0.07), Font = Enum.Font.SourceSans })
local canvasContainer = Screen:CreateElement("Frame", { Active = true, AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = Color3.fromHex("#969696"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = UDim2.fromScale(1, 1), Size = UDim2.fromScale(0.8, 1) })

local modeTitle = Screen:CreateElement("TextButton", { Text = "Delete", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextSize = 14, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BorderColor3 = Color3.fromHex("#000000"), BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.25), Size = UDim2.fromScale(1, 0.07), Font = Enum.Font.SourceSans })

background:AddChild(settingsListFrame)
settingsListFrame:AddChild(currentColorValue)
settingsListFrame:AddChild(currentColorTitle)
settingsListFrame:AddChild(modeTitle)

background:AddChild(canvasContainer)

local Window = OSLibrary.WindowHandler.Create({
	Name = "Free Paint",
	OverwriteIfExists = true,
	Color = Color3.fromHex("#282828"),
	Type = "Custom"
})

Window:AddChild(background)

-- Tables
local Pixels = {}
local PlayerCursors = {}

-- Constants
local GRID_X = 20
local GRID_Y = 20

-- Variables
local placementMode: "place" | "delete" = "place"

local ScreenDimensions: Vector2 = Screen:GetDimensions()

-- Variables
local pixelSize = UDim2.fromScale(1 / GRID_X, 1 / GRID_Y)
local currentPixelColor = currentColorValue.BackgroundColor3

InputButton({
	Keyboard = Keyboard,
	Button = currentColorTitle,
	InputText = "Enter Color3",
	Callback = function(text, playerName)
		if playerName ~= "sweetboss151" then
			return
		end
		
		local color = StringUtil.StringToColor3RGB(text)
		
		currentPixelColor = color
		currentColorValue.BackgroundColor3 = color
	end,
})

modeTitle.MouseButton1Click:Connect(function()
	if placementMode == "place" then
		placementMode = "delete"
		modeTitle.Text = "Delete"
		modeTitle.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	else
		placementMode = "place"
		modeTitle.Text = "Place"
		modeTitle.BackgroundColor3 = currentColorTitle.BackgroundColor3
	end
end)

-- Functions
local function GetPixelInPosition(position)
	for _, pixel in ipairs(Pixels) do
		if pixel.Position == position then
			return pixel
		end
	end
end

while true do
	task.wait()
	
	if Window.Destroyed then
		return "Free paint closed"
	end
		
	local allCursors = Screen:GetCursors()
	
	for playerName, cursor in pairs(allCursors) do
		if playerName ~= "sweetboss151" then
			continue
		end
		
		local pixel = PlayerCursors[playerName]
		
		if not pixel then
			pixel = Screen:CreateElement("TextLabel", {
				Size = pixelSize,
				BorderSizePixel = 0,
				BackgroundTransparency = 0.5,
				BackgroundColor3 = currentPixelColor,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(200, 200, 200),
			})
			
			canvasContainer:AddChild(pixel)
			PlayerCursors[playerName] = pixel
		end
		
		pixel.BackgroundColor3 = currentPixelColor
		pixel.Text = playerName

		local mouseX = cursor.X - ScreenDimensions.X - canvasContainer.AbsolutePosition.X
		local mouseY = cursor.Y - ScreenDimensions.X - canvasContainer.AbsolutePosition.Y
		
		if canvasContainer.AbsoluteSize.X == ScreenDimensions.X then
			mouseX = cursor.X
		end

		if canvasContainer.AbsoluteSize.Y == ScreenDimensions.Y then
			mouseY = cursor.Y
		end

		if mouseX > canvasContainer.AbsoluteSize.X or mouseX < 0 or mouseY > canvasContainer.AbsoluteSize.Y or mouseY < 0 then
			continue
		end

		--mouseX = math.clamp(mouseX, 0, canvasContainer.AbsoluteSize.X)
		--mouseY = math.clamp(mouseY, 0, canvasContainer.AbsoluteSize.Y)

		local x = math.floor(mouseX / pixel.AbsoluteSize.X) * pixel.AbsoluteSize.X
		local y = math.floor(mouseY / pixel.AbsoluteSize.Y) * pixel.AbsoluteSize.Y

		local pixelPosition = UDim2.fromOffset(x, y)

		local oldPixel = GetPixelInPosition(pixelPosition)
		
		pixel.Position = pixelPosition
		pixel.BackgroundTransparency = 0.5

		if not cursor.Pressed then
			continue
		end
		
		if oldPixel then
			if oldPixel.BackgroundColor3 ~= pixel.BackgroundColor3 then
				oldPixel:Destroy()
				table.remove(Pixels, table.find(Pixels, oldPixel))
			else
				continue
			end
		end
		
		if placementMode == "place" then
			pixel.Text = "" -- The stupid way elements work, this is required.
			local clone = pixel:Clone()
			clone.BackgroundTransparency = 0

			table.insert(Pixels, clone)
		elseif placementMode == "delete" then
			
			if oldPixel then
				oldPixel:Destroy()
				table.remove(Pixels, table.find(Pixels, oldPixel))
			end
			
		end
	end
	
	for playerName, prePixel in pairs(PlayerCursors) do

		if not allCursors[playerName] then
			prePixel:Destroy()
			PlayerCursors[playerName] = nil
		end
	end
end
