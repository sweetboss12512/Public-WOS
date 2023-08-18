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

WOS_MODULES.OperationScreenV2 = function()
	local Screen = GetPartFromPort(1, "Screen") or GetPartFromPort(1, "TouchScreen")
	
	local Components = {
		WindowTemplate = function(Parent, windowType)
			local containerTypes = {
				Scroll = {"ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.Y, BottomImage = "", ScrollBarImageColor3 = Color3.fromHex("#000000"), ScrollBarThickness = 3, TopImage = "", Active = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.9) }},
				Text = {"TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.89) }},
				Custom = {"Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.9) }}
			}
	
			local info = containerTypes[windowType] or containerTypes.Custom
	
			local windowTemplate = Screen:CreateElement("TextButton", { Text = "", TextScaled = true, TextWrapped = true, AutoButtonColor = false, Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#505050"), BorderColor3 = Color3.fromHex("#323232"), BorderSizePixel = 2, Position = UDim2.fromScale(0.5, 0.5), Selectable = false, Size = UDim2.fromScale(0.6, 0.6) })
			local contentFrame = Screen:CreateElement(info[1], info[2]) -- Content container
	
			local title = Screen:CreateElement("TextLabel", { RichText = true, TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.fromScale(0.53, 0.1) })
			local titleUnderline = Screen:CreateElement("Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#FFFFFF"), BorderSizePixel = 0, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.1) })
	
			local closeButton = Screen:CreateElement("TextButton", { Text = "X", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.1, 0.1) })
			local minimizeButton = Screen:CreateElement("TextButton", { RichText = true, Text = "-", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.8, 0), Size = UDim2.fromScale(0.1, 0.1) })
			local maximizeButton = Screen:CreateElement("TextButton", { RichText = true, Text = "+", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.9, 0), Size = UDim2.fromScale(0.1, 0.1) })
			--local contentLabel = Screen:CreateElement("TextLabel", { Text = "SOMETHING SOMETHING", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.89) })
			--local scrollFrame = Screen:CreateElement("ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.Y, BottomImage = "", ScrollBarImageColor3 = Color3.fromHex("#000000"), ScrollBarThickness = 3, TopImage = "", Active = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.9) })
			local background = Screen:CreateElement("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 })
			--local contentFrame = Screen:CreateElement("Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.9) })
	
			windowTemplate:AddChild(title)
			title:AddChild(titleUnderline)
	
			windowTemplate:AddChild(closeButton)
			windowTemplate:AddChild(minimizeButton)
			windowTemplate:AddChild(maximizeButton)
			
			windowTemplate:AddChild(background)
			windowTemplate:AddChild(contentFrame)
	
			if Parent then Parent:AddChild(windowTemplate) end
			return { minimizeButton = minimizeButton, titleUnderline = titleUnderline, background = background, maximizeButton = maximizeButton, title = title, contentFrame = contentFrame, closeButton = closeButton, windowTemplate = windowTemplate}
		end
	}
	
	-- Tables
	export type WindowConfig = {
		Type: "Text" | "Scroll" | "Custom",
		Text: string,
		Name: string,
		Color: Color3,
		WindowSize: UDim2,
		TextColor: Color3,
		Layout: any,
		Parent: GuiObject,
		BackgroundImage: any,
		OverwriteIfExists: boolean
	}
	
	local Windows = {}
	local WindowHandler = {}
	
	-- Functions
	function WindowHandler.Create(config: WindowConfig)
		if Windows[config.Name] then
			
			if config.OverwriteIfExists then -- If the window already exists
				Windows[config.Name]:Destroy()
			else
				return Windows[config.Name]
			end
		end
	
		config = config or error("No config provided")
		config.Color = config.Color or WindowHandler.DefaultConfig.Color
		config.Parent = config.Parent or WindowHandler.DefaultConfig.Parent
		config.WindowSize = config.WindowSize or UDim2.fromScale(0.6, 0.6)
		
		local self = {
			_Config = config,
			_Elements = Components.WindowTemplate(config.Parent or WindowHandler.DefaultConfig.Parent, config.Type),
			Max = false,
			Destroyed = false,
			ClassName = "WindowHandler.ScreenWindow"
		}
	
		self._Elements.title.Text = config.Name
		
		if config.BackgroundImage then
			self._Elements.background.Image = config.BackgroundImage
			
			if config.Color then
				local brighten = Screen:CreateElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 0.5,
					BackgroundColor3 = config.Color
				})
				
				self._Elements.background:AddChild(brighten)
			end
		end
		
		local mainFrame = self._Elements.windowTemplate
		local contentContainer = self._Elements.contentFrame
	
		mainFrame.Size = config.WindowSize
	
		if config.Color then
			contentContainer.BackgroundColor3 = config.Color
			mainFrame.BackgroundColor3 = config.Color
		end
	
		if config.Type == "Text" then
			contentContainer.Text = config.Text
			contentContainer.TextColor3 = config.TextColor or Color3.fromRGB(255, 255, 255)
	
		elseif config.Type == "Scroll" then
			-- NOTHING FOR NOW
		end
	
		local function MoveOutOfWay()
			if self.Max then
				return
			end
	
			for _, window in pairs(Windows) do
				if window == self then
					continue
				end
	
				while self._Elements.windowTemplate.Position == window._Elements.windowTemplate.Position do
					mainFrame.Position += UDim2.fromScale(0.05, 0.05)
				end
			end
		end
	
		-- Window methods
		function self:Maximize()
			for _, v in pairs(Windows) do
				v._Elements.windowTemplate.ZIndex = 0
			end
	
			mainFrame.ZIndex = 2
			mainFrame.Size = UDim2.fromScale(1, 1)
			mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	
			self.Max = true
			MoveOutOfWay()
		end
	
		function self:Minimize()
			if self.Max then
				mainFrame.Size = config.WindowSize
			end
	
			self.Max = false
			MoveOutOfWay()
		end
	
		function self:Destroy()
			self._Elements.windowTemplate:Destroy()
			self.Destroyed = true
			Windows[config.Name] = nil
		end
	
		function self:AddChild(child)
			if self.Layout then -- list layout/grid layout
				self.Layout:AddChild(child)
			else
				contentContainer:AddChild(child)
			end
		end
	
		MoveOutOfWay()
	
		mainFrame.MouseButton1Click:Connect(function()
			for _, window in pairs(Windows) do
				window._Elements.windowTemplate.ZIndex = 0
			end
	
			mainFrame.ZIndex = 3
		end)
	
		self._Elements.closeButton.MouseButton1Click:Connect(function()
			self:Destroy()
		end)
	
		self._Elements.maximizeButton.MouseButton1Click:Connect(function()
			self:Maximize()
		end)
	
		self._Elements.minimizeButton.MouseButton1Click:Connect(function()
			self:Minimize()
		end)
	
		Windows[config.Name] = self
		return self
	end
	
	function WindowHandler:GetWindow(windowName)
		return Windows[windowName]
	end
	
	local defaultConfig: WindowConfig = {} -- Annoying. Type checks dont appear unless its made like this.
	WindowHandler.DefaultConfig = defaultConfig
	
	return WindowHandler
end

WOS_MODULES.SpeakerHandler = function()
	local SpeakerHandler = {
		_LoopedSounds = {},
		_ChatCooldowns = {}, -- Cooldowns of Speaker:Chat
		_SoundCooldowns = {}, -- Sounds played by SpeakerHandler.PlaySound
		DefaultSpeaker = nil,
	}
	
	function SpeakerHandler.Chat(text, cooldownTime, speaker)
		speaker = speaker or SpeakerHandler.DefaultSpeaker or error("[SpeakerHandler.Chat]: No speaker provided")
	
		if SpeakerHandler._ChatCooldowns[speaker.GUID..text] then
			return
		end
	
		speaker:Chat(text)
	
		if not cooldownTime then
			return
		end
	
		SpeakerHandler._ChatCooldowns[speaker.GUID..text] = true
		task.delay(cooldownTime, function()
			SpeakerHandler._ChatCooldowns[speaker.GUID..text] = nil
		end)
	end
	
	function SpeakerHandler.PlaySound(id, pitch, cooldownTime, speaker)
		speaker = speaker or SpeakerHandler.DefaultSpeaker or error("[SpeakerHandler.PlaySound]: No speaker provided")
		id = tonumber(id)
		pitch = tonumber(pitch) or 1
	
		if SpeakerHandler._SoundCooldowns[speaker.GUID..id] then
			return
		end
	
		speaker:Configure({Audio = id, Pitch = pitch})
		speaker:Trigger()
	
		if cooldownTime then
			SpeakerHandler._SoundCooldowns[speaker.GUID..id] = true
	
			task.delay(cooldownTime, function()
				SpeakerHandler._SoundCooldowns[speaker.GUID..id] = nil
			end)
		end
	end
	
	function SpeakerHandler:LoopSound(id, soundLength, pitch, speaker)
		speaker = speaker or SpeakerHandler.DefaultSpeaker or error("[SpeakerHandler:LoopSound]: No speaker provided")
		id = tonumber(id)
		pitch = tonumber(pitch) or 1
		
		if SpeakerHandler._LoopedSounds[speaker.GUID] then
			SpeakerHandler:RemoveSpeakerFromLoop(speaker)
		end
		
		speaker:Configure({Audio = id, Pitch = pitch})
		
		SpeakerHandler._LoopedSounds[speaker.GUID] = {
			Speaker = speaker,
			Length = soundLength / pitch,
			TimePlayed = tick()
		}
		
		speaker:Trigger()
		return true
	end
	
	function SpeakerHandler:RemoveSpeakerFromLoop(speaker)
		SpeakerHandler._LoopedSounds[speaker.GUID] = nil
		
		speaker:Configure({Audio = 0, Pitch = 1})
		speaker:Trigger()
	end
	
	function SpeakerHandler:UpdateSoundLoop(dt) -- Triggers any speakers if it's time for them to be triggered
		dt = dt or 0
		
		for _, sound in pairs(SpeakerHandler._LoopedSounds) do
			local currentTime = tick() - dt
			local timePlayed = currentTime - sound.TimePlayed
	
			if timePlayed >= sound.Length then
				sound.TimePlayed = tick()
				sound.Speaker:Trigger()
			end
		end
	end
	
	function SpeakerHandler:StartSoundLoop() -- If you use this, you HAVE to put it at the end of your code.
		
		while true do
			local dt = task.wait()
			SpeakerHandler:UpdateSoundLoop(dt)
		end
	end
	
	function SpeakerHandler.CreateSound(config: { Id: number, Pitch: number, Length: number, Speaker: any } ) -- Psuedo sound object, kinda bad
		config.Pitch = config.Pitch or 1
		
		local sound = {
			ClassName = "SpeakerHandler.Sound",
			Id = config.Id,
			Pitch = config.Pitch,
			_Speaker = config.Speaker or SpeakerHandler.DefaultSpeaker or error("[SpeakerHandler.CreateSound]: A speaker must be provided"),
			_OnCooldown = false, -- For sound cooldowns
			_Looped = false
		}
		
		if config.Length then
			sound.Length = config.Length / config.Pitch
		end
		
		function sound:Play(cooldownSeconds)
			if sound._OnCooldown then
				return
			end
			
			sound._Speaker:Configure({Audio = sound.Id, Pitch = sound.Pitch})
			sound._Speaker:Trigger()
			
			if not cooldownSeconds then
				return
			end
			
			sound._OnCooldown = true
			task.delay(cooldownSeconds, function()
				sound._OnCooldown = false
			end)
		end
		
		function sound:Stop()
			sound._Speaker:Configure({Audio = 0, Pitch = 1})
			sound._Speaker:Trigger()
			
			sound._OnCooldown = false
		end
		
		function sound:Loop()
			sound._Looped = true
			SpeakerHandler:LoopSound(sound.Id, sound.Length, sound.Pitch, sound._Speaker)
		end
		
		function sound:Destroy()
			if sound._Looped then
				SpeakerHandler:RemoveSpeakerFromLoop(sound._Speaker)
			end
			
			table.clear(sound)
		end
		
		return sound
	end
	
	return SpeakerHandler
end

--

-- Modules
local SpeakerHandler = require("SpeakerHandler")
local WindowHandler = require("OperationScreenV2")

-- Objects
local Screen = GetPartFromPort(1, "Screen")
local Speaker = GetPartFromPort(1, "Speaker")
local Disk = GetPartFromPort(1, "Disk")
local Mircophone = GetPartFromPort(1, "Microphone")
local Keyboard = GetPartFromPort(2, "Keyboard")

-- Screen Objects
Screen:ClearElements()

SpeakerHandler.DefaultSpeaker = Speaker

-- Tables
local Commands = {}
local CommandNames = {}
local Users = {["sweetboss151"] = math.huge}
local AssistantConfig: {
	Users: { [string]: number },
	ShorterUsers: { [string]: string  }
	
} = Disk:Read("AssistantConfig")

--local Sounds = {
--	AccessDenied = 131644951,
--	BootUp = 5188022160,
--	Error = 5914602124,
--	--Synthwar = 4580911200,
--}

local Sounds = {
	AccessDenied = SpeakerHandler.CreateSound({ Id = 131644951, Pitch = 0.8 }),
	BootUp = SpeakerHandler.CreateSound({ Id = 5188022160, Pitch = 0.8 }),
	Error = SpeakerHandler.CreateSound({ Id = 5914602124 })
}

-- Constants
local ASSISTANT_PREFIX = "TBD"

-- Functions
local function FindCommandFromSentence(str: string)
	str = str:lower()
	
	for _, command in pairs(Commands) do
		
		for _, word in ipairs(command.Keywords) do
			local matchStr = `.*{word:gsub(" ", ".*")}.*`

			print(matchStr)
			print(str)
			print("")
			if str:match(matchStr) then
				return command
			end
		end
	end
end

local function WindowResponse(text, properties: WindowHandler.WindowConfig)
	local propertyList: WindowHandler.WindowConfig = {
		Name = ASSISTANT_PREFIX..":",
		Type = "Text",
		Text = text
	}

	if properties then
		for i, v in pairs(properties) do
			propertyList[i] = v
		end
	end

	local window = WindowHandler.Create(propertyList)

	
	if window._Elements.contentFrame.Text:match("#") and not text:match("#") then
		task.wait(0.1)
		window._Elements.contentFrame.Text = "My text was filtered"
		SpeakerHandler.Chat(text)
	end

	return window
end

local function CommandInput(text: string, playerName: string)
	if not Users[playerName] then
		SpeakerHandler.Chat("Access Denied", 3)
		Sounds.AccessDenied:Play(3)
		return
	end
	
	local command = FindCommandFromSentence(text)
	local arguments

	if command then
		arguments = text
	else
		arguments = text:split(" ")
		command = CommandNames[arguments[1]:lower()]
	end

	if not command then
		print("Command not found")
		return
	end

	local success, returned = pcall(command.Callback, arguments, playerName)

	if not success then
		Sounds.Error:Play()
		WindowResponse("I encountered an error. Please check the error logs.", {Color = BrickColor.new("Really red").Color})
		print(returned)
	end

	if returned then
		SpeakerHandler.Chat(returned)
	end
end

-- Setup
if not AssistantConfig then
	AssistantConfig = {
		Users = { ["sweetboss151"] = math.huge },
		ShorterUsers = { ["sweetboss151"] = "sweetboss" }
	}
	
	Disk:Write("AssistantConfig", AssistantConfig)
end

Keyboard:Connect("TextInputted", function(text: string, playerName: string)
	text = text:sub(1, -2)
	CommandInput(text, playerName)
end)

Mircophone:Connect("Chatted", function(playerName, message)
	if not Users[playerName] then
		return
	end
	
	local split = message:split(" ")
	local prefix = split[1]:gsub(",", "")
	
	table.remove(split, 1)
	message = table.concat(split, " ")
	
	if prefix:lower():match(`^{ASSISTANT_PREFIX:lower()}`) then
		print("Match")
		CommandInput(message, playerName)
	end
end)

Commands.ShowLocation = {
	Keywords = { "where am i" },
	Callback = function()
		return "I dont know where this is"
	end,
}

Commands.Greet = {
	Keywords = { "how are you" },
	Callback = function(_, user)
		return `I'm fine, {AssistantConfig.ShorterUsers[user] or user}.`
	end,
}

Commands[ASSISTANT_PREFIX] = {
	Keywords = { ASSISTANT_PREFIX },
	Callback = function(_, user)
		return `Yes, {AssistantConfig.ShorterUsers[user] or user}?`
	end,
}

for mainName, command in pairs(Commands) do
	command.Name = mainName

	if command.Keywords then

		for i, word in ipairs(command.Keywords) do
			command.Keywords[i] = word:lower()
		end
	else
		print(`Command '{mainName} has no keywords table`)
	end

	if command.Usages then
		for _, usage in pairs(command.Usages) do
			CommandNames[usage:lower()] = command
		end
	end

	if not command.Rank then
		command.Rank = 1
	end
end

Sounds.BootUp:Play()
WindowResponse("All systems online, greetings.")
