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

WOS_MODULES.TableUtility = function()
	local module = {}
	
	function module.DeepCopy(tble)
		local copy = {}
	
		for i, v in pairs(tble) do
			if typeof(v) == "table" then
				copy[i] = module.DeepCopy(v)
			else
				copy[i] = v
			end
		end
		
		return copy
	end
	
	function module.FromDictKeys(tble)
		local keys = {}
		
		for i in pairs(tble) do
			table.insert(keys, i)
		end
		
		return ipairs(keys)
	end
	
	function module.CountKeys(tble)
		local count = 0
		
		for _ in pairs(tble) do
			count += 1
		end
		
		return count
	end
	
	function module.RandomFromDict(dict)
		local keys = {}
		
		for i in pairs(dict) do
			table.insert(keys, i)
		end
		
		local chosen = keys[math.random(1, #keys)]
		
		return chosen, dict[chosen]
	end
	
	function module.PrintTable(tble, indent) -- just for WOS debuging
		local snippet = setmetatable({}, { __index = table })
		indent = indent or 1
		
		snippet:insert("{")
		local indentStr = string.rep("\t", indent)
		
		for index, value in tble do
			if type(value) == "table" then
				value = module.PrintTable(value, indent + 1)
			end
			
			snippet:insert(`{indentStr}[{index}] = {value}`)
		end
		
		snippet:insert("}")
		
		local str = table.concat(snippet, "\n")
		return str
	end 
	
	return module
end

WOS_MODULES.MusicPlayerIds = function()
	local module = {
		AccessDenied = 131644951,
		BootUp = 5188022160,
		Error = 5914602124,
		Synthwar = 4580911200,
		["DISTANT OMG"] = 4611202823,
	
		Blade = 10951049295,
		Climber = 10951047950,
		["Synthwar!!!"] = 12028872937,
	}
	
	--6667206702 length:2.763 pitch:1.5
	
	return module
end

WOS_MODULES.Radar = function()
	local Screen = GetPartFromPort(1, "Screen") or GetPartFromPort(1, "TouchScreen")
	local LifeSensor = GetPartFromPort(1, "LifeSensor") or GetPartFromPort(2, "LifeSensor")
	
	-- Templates
	local radarTemplate = { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.1) }
	local radarTemplate_Dot = { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#FFFFFF"), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3) }
	local radarTemplate_NameLabel = { Text = "sweetboss151", TextColor3 = Color3.fromHex("#FFFFFF"), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, -0.5), Size = UDim2.fromScale(1, 0.5) }
	local radarTemplate_PositionLabel = { RichText = true, Text = "100", TextColor3 = Color3.fromHex("#FFFFFF"), AnchorPoint = Vector2.new(0.5, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromHex("#FFFFFF"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, -0.9), Size = UDim2.fromScale(1, 0.5), ZIndex = 2 }
	local radarTemplate_Direction = { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#FFFFFF"), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 0 }
	local radarTemplate_Direction_Label = { Image = "http://www.roblox.com/asset/?id=6798365555", Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.15), Size = UDim2.fromScale(0.5, 0.3), ZIndex = 0 }
	
	-- Tables
	local RadarElements = {}
	local PlayerPositions = {} -- For calculating velocity
	
	local NAME_COLORS = { -- Pasted from devforum.
		Color3.new(253/255, 41/255, 67/255), -- BrickColor.new("Bright red").Color,
		Color3.new(1/255, 162/255, 255/255), -- BrickColor.new("Bright blue").Color,
		Color3.new(2/255, 184/255, 87/255), -- BrickColor.new("Earth green").Color,
		BrickColor.new("Bright violet").Color,
		BrickColor.new("Bright orange").Color,
		BrickColor.new("Bright yellow").Color,
		BrickColor.new("Light reddish violet").Color,
		BrickColor.new("Brick yellow").Color,
	}
	
	local RadarModes = {
		"Static",
		"Rotate"
	}
	
	-- Constants
	local X_MAX = 2010
	local Y_MAX = 2010
	local VEHICLE_SEAT_PORT = 2
	
	-- Variables
	local radarMode = RadarModes[1]
	-- Functions
	local function GetNameValue(pName)
		local value = 0
	
		for index = 1, #pName do
	
			local cValue = string.byte(string.sub(pName, index, index))
			local reverseIndex = #pName - index + 1
	
			if #pName % 2 == 1 then
				reverseIndex = reverseIndex - 1
			end
	
			if reverseIndex % 4 >= 2 then
				cValue = -cValue
			end
			value = value + cValue
		end
	
		return value
	end
	
	local function ComputeNameColor(pName)
		return NAME_COLORS[((GetNameValue(pName) + 0) % #NAME_COLORS) + 1]
	end
	
	local function GetAngleBetween(pos1: Vector2, pos2: Vector2)
		local Origin: Vector2 = pos1
		local LookAt: Vector2 = pos2
	
		local Angle = math.atan2(
			Origin.Y - LookAt.Y,
			Origin.X - LookAt.X
		)
	
		return math.deg(Angle)
	end
	
	-- Functions
	local function CreatePlayerRadar(playerName, radarList)
		radarTemplate_NameLabel.Text = playerName
		radarTemplate_Dot.BackgroundColor3 = ComputeNameColor(playerName)
	
		local container = Screen:CreateElement("Frame", radarTemplate)
		local radarDot = Screen:CreateElement("Frame", radarTemplate_Dot)
		local nameLabel = Screen:CreateElement("TextLabel", radarTemplate_NameLabel)
		local positionLabel = Screen:CreateElement("TextLabel", radarTemplate_PositionLabel)
	
		local directionFrame = Screen:CreateElement("Frame", radarTemplate_Direction)
		local directionFrameLabel = Screen:CreateElement("ImageLabel", radarTemplate_Direction_Label)
		
		radarList:AddChild(container)
	
		container:AddChild(radarDot)
		container:AddChild(nameLabel)
		container:AddChild(directionFrame)
		container:AddChild(positionLabel)
	
		directionFrame:AddChild(directionFrameLabel)
	
		local info = {
			Container = container,
			DirectionFrame = directionFrame,
			PositionLabel = positionLabel
		}
	
		RadarElements[playerName] = info
	
		return info
	end
	
	local function CalculateCompassRotation()
		local orientationVector
	
		if GetPartFromPort(VEHICLE_SEAT_PORT, "VehicleSeat") then
			orientationVector = GetPartFromPort(VEHICLE_SEAT_PORT, "VehicleSeat").CFrame.LookVector * -1
		else
			orientationVector = Screen.CFrame.UpVector
		end
	
		local dot = orientationVector:Dot(Vector3.new(0, 0, 1))
		return math.deg(math.acos(dot)) * if orientationVector.X > 0 then 1 else -1
	end
	
	local function Radar(window)
		if not LifeSensor then
			return "A lifesensor is required on port #1 For the Radar module."
		end
		
		local maxLabelX = Screen:CreateElement("TextLabel", { Text = "X - 2048", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.1), Font = Enum.Font.Code })
		local maxLabelY = Screen:CreateElement("TextLabel", { Text = "Y - 2048", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(-0.2, 0.5), Rotation = -90, Size = UDim2.fromScale(0.5, 0.1), Font = Enum.Font.Code })
		local radarList = Screen:CreateElement("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#2D2D2D"), BorderColor3 = Color3.fromHex("#282828"), BorderSizePixel = 5, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8) })
		local radarModeButton = Screen:CreateElement("TextButton", { Text = "RELATIVE", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = Color3.fromHex("#3C3C3C"), BorderColor3 = Color3.fromHex("#000000"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 3, Position = UDim2.fromScale(1, 1), Size = UDim2.fromScale(0.2, 0.1) })
		local gridCenter = Screen:CreateElement("ImageLabel", { Image = "http://www.roblox.com/asset/?id=12072054746", ScaleType = Enum.ScaleType.Crop, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.03, 0.03), ZIndex = 0 })
	
		local compassContainer = Screen:CreateElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		local compassContainer_North = Screen:CreateElement("TextLabel", { RichText = true, Text = "<u>N</u>", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.05) })
		local compassContainer_South = Screen:CreateElement("TextLabel", { RichText = true, Text = "<u>S</u>", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.05) })
		local compassContainer_East = Screen:CreateElement("TextLabel", { RichText = true, Text = "<u>E</u>", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromScale(0.1, 0.05) })
		local compassContainer_West = Screen:CreateElement("TextLabel", { RichText = true, Text = "<u>W</u>", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.1, 0.05)})
		
		radarList:AddChild(gridCenter)
		radarList:AddChild(compassContainer)
		compassContainer:AddChild(compassContainer_North)
		compassContainer:AddChild(compassContainer_South)
		compassContainer:AddChild(compassContainer_East)
		compassContainer:AddChild(compassContainer_West)
		
		window:AddChild(radarList)
		window:AddChild(maxLabelX)
		window:AddChild(maxLabelY)
		window:AddChild(radarModeButton)
		
		task.wait(1)
		maxLabelX.Text = X_MAX
		maxLabelY.Text = Y_MAX
	
		radarModeButton.MouseButton1Click:Connect(function()
			local newIndex = table.find(RadarModes, radarMode) + 1
	
			if newIndex > #RadarModes then
				newIndex = 1
			end
	
			radarMode = RadarModes[newIndex]
			radarModeButton.Text = radarMode:upper()
		end)
		
		while not window.Destroyed do
			local waitTime = task.wait()
			local players = LifeSensor:GetReading()
			LifeSensor = GetPartFromPort(1, "LifeSensor") or GetPartFromPort(2, "LifeSensor") -- Update their CFrames
			Screen = GetPartFromPort(1, "Screen") or GetPartFromPort(1, "TouchScreen")
	
			if radarMode == "Rotate" then
				local rotation = CalculateCompassRotation()
	
				compassContainer.Rotation = rotation
				compassContainer_North.Rotation = -rotation
				compassContainer_South.Rotation = -rotation
				compassContainer_East.Rotation = -rotation
				compassContainer_West.Rotation = -rotation
			else
				compassContainer.Rotation = 0
				compassContainer_North.Rotation = 0
				compassContainer_South.Rotation = 0
				compassContainer_East.Rotation = 0
				compassContainer_West.Rotation = 0
			end
	
			for playerName, position in pairs(players) do
				--if playerName ~= "sweetboss151" then
				--	continue
				--end
				position = (position - LifeSensor.CFrame.Position)
	
				local radarInfo = RadarElements[playerName] or CreatePlayerRadar(playerName, radarList)
				local container = radarInfo.Container
				local directionFrame = radarInfo.DirectionFrame
	
				local oldPosition = container.AbsolutePosition
	
				local xScale = (position.X / X_MAX)
				local zScale = (position.Z / Y_MAX)
	
				container.Position = UDim2.fromScale(math.clamp(xScale + 0.5, 0, 1), math.clamp(zScale + 0.5, 0, 1))
				radarInfo.PositionLabel.Text = if position.Y > 10 then math.floor(position.Y) else 0
	
				if (oldPosition - container.AbsolutePosition).Magnitude < (waitTime / 2) then
					directionFrame.Size = UDim2.fromScale(0, 0)
					continue
				end
	
				directionFrame.Size = radarTemplate_Direction.Size
				directionFrame.Rotation = GetAngleBetween(oldPosition, container.AbsolutePosition) - 90 + compassContainer.Rotation
			end
	
			for name, info in pairs(RadarElements) do
				if not players[name] then
					RadarElements[name] = nil
					info.Container:Destroy()
				end
			end
		end
		
		print("LOOP ENDED")
	end
	
	return Radar
end

WOS_MODULES.ListLayoutV2 = function()
	export type ListLayoutInfo = {
		Padding: UDim,
		StartPosition: UDim,
		CenterObjects: boolean,
		FillDirection: Enum.FillDirection,
		HorizontalAlignment: Enum.HorizontalAlignment
	}
	
	local function ListLayout(parent, config: ListLayoutInfo): ListLayout
		local layout = {
			Parent = parent,
			_Children = {},
			_Config = config
		}
		
		config.FillDirection = config.FillDirection or Enum.FillDirection.Vertical
		config.StartPosition = config.StartPosition or UDim.new(0, 0)
		config.Padding = config.Padding or UDim.new(0, 0)
		
		function layout:AddChild(screenObject)
			if not layout.Parent then
				error("[ListLayout:AddChild]: ListLayout has no parent")
			end
			
			if table.find(layout._Children, screenObject) then
				return
			end
	
			local position
			local lastChild = layout._Children[#layout._Children]
	
			if config.FillDirection == Enum.FillDirection.Vertical then
				position = UDim2.new(0, 0, config.StartPosition.Scale, config.StartPosition.Offset)
	
				if lastChild then
					local yScale = lastChild.Position.Y.Scale + lastChild.Size.Y.Scale
					local yOffset = lastChild.Position.Y.Offset + lastChild.Size.Y.Offset
	
					position = UDim2.new(0, 0, yScale + config.Padding.Scale, yOffset + config.Padding.Offset)
				end
	
				if config.CenterObjects then
					screenObject.AnchorPoint = Vector2.new(0.5, screenObject.AnchorPoint.Y)
					position += UDim2.fromScale(0.5, 0)
				end
	
			elseif config.FillDirection == Enum.FillDirection.Horizontal then
				position = UDim2.new(config.StartPosition.Scale, config.StartPosition.Offset, 0, 0)
	
				if lastChild then
					local xScale = lastChild.Position.X.Scale + lastChild.Size.X.Scale
					local xOffset = lastChild.Position.X.Offset + lastChild.Size.X.Offset
	
					position = UDim2.new(xScale + config.Padding.Scale, xOffset + config.Padding.Offset, 0, 0)
				end
				
				if config.CenterObjects then
					screenObject.AnchorPoint = Vector2.new(0.5, screenObject.AnchorPoint.X)
					position += UDim2.fromScale(0, 0.5)
				end
			else
				error("[LIST LAYOUT]: Invalid fill direction. FillDirection must be An Enum.FillDirection")
			end
	
			screenObject.Position = position
			layout.Parent:AddChild(screenObject)
			table.insert(layout._Children, screenObject)
		end
	
		function layout:Refresh()
			local oldChildren = layout._Children
			layout._Children = {}
	
			for _, v in ipairs(oldChildren) do
				layout:AddChild(v)
			end
	
			oldChildren = nil
		end
	
		function layout:Remove(childIndex, destroyChild: boolean)
			local index = childIndex
	
			if typeof(childIndex) ~= "number" then
				index = table.find(layout._Children, childIndex)
			end
	
			if not index then
				--print(("[LIST LAYOUT]: Child was not found. Cannot remove."))
				return
			end
	
			local child = layout._Children[index]
			table.remove(layout._Children, index)
	
			if destroyChild then
				child:Destroy()
			end
	
			layout:Refresh()
		end
	
		function layout:Destroy()
			table.clear(layout)
		end
	
		return layout
	end
	
	export type ListLayout = typeof(ListLayout())
	
	return ListLayout
end

WOS_MODULES.PilotLua = function()
	-- Made by ArvidSilverlock
	
	type Part = "Port" | "Gyro" | "Keyboard" | "Microphone" | "LifeSensor" | "Instrument" | "EnergyShield" | "Disk" | "Bin" | "Modem" | "Screen" | "TouchSensor" | "Rail" | "StarMap" | "Telescope" | "Speaker" | "Reactor" | "Dispenser" | "Polysilicon" | "Microcontroller" | "HyperDrive" | "BlackBox"
	
	type JSONValue = string | number | boolean
	type JSON = { [JSONValue]: JSON } | JSONValue
	
	type EventConnector<self, events> = (self: self, event: events | "Triggered" | "Configured", callback: (...any) -> ()) -> Connection
	
	type DefaultEvents<self> = (self: self, event: "Triggered" | "Configured", callback: (...any) -> ()) -> Connection
	type DefaultConfigure<self> = (self: self, properties: { [string]: nil }) -> ()
	
	type PilotObject = {
		GetColor: (self: PilotObject) -> Color3,
		GetSize: (self: PilotObject) -> Vector3,
		Trigger: (self: PilotObject) -> (),
		GUID: string,
		Position: Vector3,
		CFrame: CFrame,
		[string]: any,
	}
	
	export type Other = {
		Configure: (self: Other, properties: { [string]: any }) -> (),
		Connect: EventConnector<Other, string>,
		[string]: any,
	} & PilotObject
	
	export type Port = {
		ClassName: "Port",
		Connect: DefaultEvents<Port>,
		Configure: DefaultConfigure<Port>,
	} & PilotObject
	
	export type Gyro = {
		ClassName: "Gyro",
	
		PointAt: (self: Gyro, position: Vector3) -> (),
	
		Connect: DefaultEvents<Gyro>,
		Configure: (self: Gyro, properties: {
			Seek: string?,
			MaxTorque: Vector3?,
			DisableWhenUnpowered: boolean?,
			TriggerWhenSeeked: boolean?,
		}) -> (),
	
		Seek: string?,
		MaxTorque: Vector3?,
		DisableWhenUnpowered: boolean?,
		TriggerWhenSeeked: boolean?,
	} & PilotObject
	
	export type Keyboard = {
		ClassName: "Keyboard",
	
		SimulateKeyPress: (self: Keyboard, key: string?, Player: string) -> (),
		SimulateTextInput: (self: Keyboard, input: string?, Player: string) -> (),
	
		Connect: EventConnector<Keyboard, "TextInputted" | "KeyPressed">,
		Configure: DefaultConfigure<Keyboard>,
	} & PilotObject
	
	export type Microphone = {
		ClassName: "Microphone",
	
		Connect: EventConnector<Microphone, "Chatted">,
		Configure: DefaultConfigure<Microphone>,
	} & PilotObject
	
	export type LifeSensor = {
		ClassName: "LifeSensor",
	
		GetReading: (self: LifeSensor) -> { [string]: Vector3 },
	
		Connect: DefaultEvents<LifeSensor>,
		Configure: DefaultConfigure<LifeSensor>,
	} & PilotObject
	
	export type Instrument = {
		ClassName: "Instrument",
	
		GetReading: (self: Instrument, typeId: number?) -> any,
	
		Connect: DefaultEvents<Instrument>,
		Configure: (self: Instrument, properties: {
			Type: number?
		}) -> (),
	
		Type: number
	} & PilotObject
	
	export type EnergyShield = {
		ClassName: "EnergyShield",
	
		GetShieldHealth: (self: EnergyShield) -> number,
	
		Connect: DefaultEvents<EnergyShield>,
		Configure: (self: EnergyShield, properties: {
			ShieldRadius: number?,
			RegenerationSpeed: number?,
			ShieldStrength: number?
		}) -> (),
	
		ShieldRadius: number,
		RegenerationSpeed: number,
		ShieldStrength: number
	} & PilotObject
	
	export type Disk = {
		ClassName: "Disk",
	
		ClearDisk: (self: Disk) -> (),
		Write: (self: Disk, key: any, data: any) -> number,
		Read: (self: Disk, key: any) -> number,
		ReadEntireDisk: (self: Disk) -> { [string]: string },
	
		Connect: DefaultEvents<Disk>,
		Configure: DefaultConfigure<Disk>,
	} & PilotObject
	
	export type Bin = {
		ClassName: "Bin",
	
		GetAmount: (self: Bin) -> number,
		GetResource: (self: Bin) -> string,
	
		Connect: DefaultEvents<Bin>,
		Configure: (self: Bin, properties: {
			CanBeCraftedFrom: boolean
		}) -> ()
	
	} & PilotObject
	
	export type Modem = {
		ClassName: "Modem",
	
		PostRequest: (self: Modem, domain: string, data: string) -> (),
		GetRequest: (self: Modem, domain: string) -> (),
		SendMessage: (self: Modem, data: string, id: number) -> (),
		RealPostRequest: (self: Modem, domain: string, data: string, async: boolean, transformFunction: (succes: boolean, response: { [string]: any }) -> (), optionalHeaders: { string }?) -> (),
	
		Connect: EventConnector<Modem, "MessageSent">,
		Configure: (self: Modem, properties: {
			NetworkID: number?
		}) -> (),
	
		NetworkID: number
	} & PilotObject
	
	export type Screen = {
		ClassName: "Screen",
	
		GetDimensions: (self: Screen) -> Vector2,
		ClearElements: (self: Screen, className: string?, properties: { [string]: any }?) -> (),
		CreateElement: (self: Screen, className: string, properties: { [string]: any }) -> ScreenObject,
	
		Connect: DefaultEvents<Screen>,
		Configure: (self: Screen, properties: {
			VideoID: number?
		}) -> (),
	
		VideoID: number
	} & PilotObject
	
	export type TouchScreen = {
		ClassName: "TouchScreen",
	
		GetCursor: (self: TouchScreen) -> Cursor,
		GetCursors: (self: TouchScreen) -> { Cursor },
	
		GetDimensions: (self: TouchScreen) -> Vector2,
		ClearElements: (self: TouchScreen, className: string?, properties: { [string]: any }?) -> (),
		CreateElement: (self: TouchScreen, className: string, properties: { [string]: any }) -> ScreenObject,
	
		Connect: EventConnector<TouchScreen, "CursorMoved" | "CursorPressed" | "CursorReleased">,
		Configure: (self: TouchScreen, properties: {
			VideoID: number?
		}) -> (),
	
		VideoID: number
	} & PilotObject
	
	export type TouchSensor = {
		ClassName: "TouchSensor",
	
		Connect: EventConnector<TouchSensor, "Touched">,
		Configure: DefaultConfigure<TouchSensor>,
	} & PilotObject
	
	export type Rail = {
		ClassName: "Rail",
	
		SetPosition: (self: Rail, depth: number) -> (),
	
		Connect: DefaultEvents<Rail>,
		Configure: (self: Instrument, properties: {
			Position1: number?,
			Position2: number?,
			TweenTime: number?
		}) -> (),
	
		Position1: number,
		Position2: number,
		TweenTime: number
	} & PilotObject
	
	export type StarMap = {
		ClassName: "StarMap",
	
		GetBodies: (self: StarMap) -> (CoordinateIterator, any, number),
		GetSystems: (self: StarMap) -> (CoordinateIterator, any, number),
	
		Connect: DefaultEvents<StarMap>,
		Configure: DefaultConfigure<StarMap>,
	} & PilotObject
	
	export type Telescope = {
		ClassName: "Telescope",
	
		GetCoordinate: (self: Telescope, X1: string?, Y1: string?, X2: string?, Y2: string?) -> RegionInfo,
		WhenRegionLoads: (self: Telescope, callback: () -> ()) -> any,
	
		Connect: EventConnector<Telescope, "WhenRegionLoads">,
		Configure: (self: Telescope, properties: {
			ViewCoordinates: string?
		}) -> (),
	
		ViewCoordinates: string
	} & PilotObject
	
	export type Speaker = {
		ClassName: "Speaker",
	
		PlaySound: (self: Speaker, id: number) -> (),
		ClearSounds: (self: Speaker) -> (),
		Chat: (self: Speaker, message: string) -> (),
	
		Connect: DefaultEvents<Speaker>,
		Configure: (self: Speaker, properties: {
			Pitch: number?,
			Audio: string?,
		}) -> (),
	
		Pitch: number,
		Audio: string
	} & PilotObject
	
	export type Reactor = {
		ClassName: "Reactor",
	
		GetFuel: (self: Reactor) -> { number },
		GetTemp: (self: Reactor) -> number,
	
		Connect: DefaultEvents<Reactor>,
		Configure: (self: Reactor, properties: {
			Alarm: boolean?,
		}) -> (),
	
		Alarm: boolean
	} & PilotObject
	
	export type Dispenser = {
		ClassName: "Dispenser",
		Dispense: (self: Dispenser) -> (),
	
		Connect: DefaultEvents<Dispenser>,
		Configure: (self: Dispenser, properties: {
			Filter: string?,
		}) -> (),
	
		Filter: string
	} & PilotObject
	
	export type Polysilicon = {
		ClassName: "Polysilicon",
	
		Connect: DefaultEvents<Polysilicon>,
		Configure: (self: Polysilicon, properties: {
			PolysiliconMode: number?,
			Frequency: number?
		}) -> (),
	
		PolysiliconMode: number,
		Frequency: number
	} & PilotObject
	
	export type Microcontroller = {
		ClassName: "Microcontroller",
		Communicate: (...any) -> (...any),
	
		Connect: DefaultEvents<Microcontroller>,
		Configure: (self: Microcontroller, properties: {
			Code: string?,
		}) -> (),
	} & PilotObject
	
	export type Servo = {
		ClassName: "Servo",
	
		SetAngle: (self: Servo, angle: number) -> (),
	
		Connect: DefaultEvents<Servo>,
		Configure: (self: Servo, properties: {
			Responsiveness: number,
			ServoSpeed: number?,
			AngleStep: number?
		}) -> (),
	
		Responsiveness: number,
		ServoSpeed: number,
		AngleStep: number
	} & PilotObject
	
	export type HyperDrive = {
		ClassName: "HyperDrive",
	
		GetRequiredPower: (self: HyperDrive) -> number,
	
		Connect: DefaultEvents<HyperDrive>,
		Configure: (self: HyperDrive, properties: {
			Coordinates: string?,
		}) -> (),
	
		Coordinates: string
	} & PilotObject
	
	export type BlackBox = {
		ClassName: "BlackBox",
		Connect: EventConnector<BlackBox, "GetLogs">,
		Configure: DefaultConfigure<BlackBox>,
	} & PilotObject
	
	export type Switch = {
		ClassName: "Switch",
		Connect: DefaultEvents<Switch>,
		Configure: (self: Switch, properties: {
			SwitchValue: boolean?,
		}) -> (),
	
		SwitchValue: boolean
	} & PilotObject
	
	export type Light = {
		ClassName: "Light",
		Connect: DefaultEvents<Light>,
		Configure: (self: Light, properties: {
			Brightness: number?,
			LightRange: number?,
		}) -> (),
	
		Brightness: number,
		LightRange: number
	} & PilotObject
	
	export type PowerCell = {
		ClassName: "PowerCell",
		Connect: DefaultEvents<PowerCell>,
		Configure: DefaultConfigure<PowerCell>,
		
		GetAmount: (self: PowerCell) -> number
		
	} & PilotObject
	
	export type VehicleSeat = {
		ClassName: "VehicleSeat",
		Connect: DefaultEvents<VehicleSeat>,
		Configure: (self: VehicleSeat, properties: {
			Enabled: boolean,
			Speed: number,
			Mode: number
		}) -> ()
	} & PilotObject
	
	export type Anchor = {
		ClassName: "Anchor",
		Connect: DefaultEvents<Anchor>,
		Configure: (self: Anchor, properties: {
			Anchored: boolean
		}) -> ()
	} & PilotObject
	
	export type Constructor = {
		ClassName: "Constructor",
		Connect: DefaultEvents<Constructor>,
		Configure: (self: Constructor, properties: {
			ModelCode: string,
			Autolock: boolean,
			RelativeToConstructor: boolean
		}) -> ()
	} & PilotObject
	
	export type Connection = {
		Unbind: (self: Connection) -> ()
	}
	
	export type Thruster = {
		ClassName: "Thruster",
		Connect: DefaultEvents<Thruster>,
		Configure: (self: Thruster, properties: {
			Propulsion: number
		}) -> ()
	} & PilotObject
	
	export type CoordinateIterator = (invariant: any, index: number) -> (nil, string)
	
	export type RegionInfo = {
		Type: "Planet",
		SubType: nil,
		Name: string,
		TidallyLocked: boolean,
		HasRings: boolean,
		BeaconCount: number
	} | {
		Type: "Planet",
		SubType: "Desert" | "Terra" | "EarthLike" | "Ocean" | "Tundra" | "Forest" | "Exotic" | "Barren" | "Gas",
		Name: string,
		Color: Color3,
		Resources: { string },
		Gravity: number,
		HasAtmosphere: boolean,
		TidallyLocked: boolean,
		HasRings: boolean,
		BeaconCount: number
	} | {
		Type: "BlackHole",
		Name: string,
		Size: number,
		BeaconCount: number
	} | {
		Type: "Star",
		SubType: "Red" | "Orange" | "Yellow" | "Blue" | "Neutron",
		Name: string,
		Size: number,
		BeaconCount: number
	}
	
	export type ScreenObject = {
		ChangeProperties: (self: ScreenObject, Properties: { [string]: any }) -> (),
		AddChild: (self: ScreenObject, Child: ScreenObject) -> (),
		Destroy: (self: ScreenObject) -> (),
		[string]: any
	}
	
	export type Cursor = {
		X: number,
		Y: number,
		Player: string,
		Pressed: boolean
	}
	
	local f = function(...) return end
	
	return {
		GetPartFromPort = f :: (port: number | PilotObject, partType: Part | string) -> PilotObject,
		GetPartsFromPort = f :: (port: number | PilotObject, partType: Part | string) -> {PilotObject},
	
		JSONEncode = f :: (data: JSON) -> string,
		JSONDecode = f :: (json: string) -> JSON,
	
		TriggerPort = f :: (port: number | PilotObject) -> (),
		GetPort = f :: (port: number) -> Port,
	
		Beep = f :: (pitch: number) -> ()
	}
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
		
		if SpeakerHandler._LoopedSounds[speaker.GUID] then
			SpeakerHandler.RemoveSpeakerFromLoop(speaker)
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
	
	function SpeakerHandler.LoopSound(id, soundLength, pitch, speaker)
		speaker = speaker or SpeakerHandler.DefaultSpeaker or error("[SpeakerHandler.LoopSound]: No speaker provided")
		id = tonumber(id)
		pitch = tonumber(pitch) or 1
		
		if not soundLength then
			error("[SpeakerHandler.LoopSound]: The length of the sound must be defined")
		end
		
		if SpeakerHandler._LoopedSounds[speaker.GUID] then
			SpeakerHandler.RemoveSpeakerFromLoop(speaker)
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
	
	function SpeakerHandler.RemoveSpeakerFromLoop(speaker)
		if not SpeakerHandler._LoopedSounds[speaker.GUID] then
			return
		end
		
		speaker:Configure({Audio = 0, Pitch = 1})
		speaker:Trigger()
		SpeakerHandler._LoopedSounds[speaker.GUID] = nil
	end
	
	function SpeakerHandler:UpdateSoundLoop(dt) -- Triggers any speakers if it's time for them to be triggered
		dt = dt or 0
		
		for _, info in pairs(SpeakerHandler._LoopedSounds) do
			local currentTime = tick() - dt
			local timePlayed = currentTime - info.TimePlayed
	
			if timePlayed >= info.Length then
				info.TimePlayed = tick()
				info.Speaker:Trigger()
			end
		end
	end
	
	function SpeakerHandler:StartSoundLoop() -- If you use this, you HAVE to put it at the end of your code.
		
		while true do
			local dt = task.wait()
			SpeakerHandler:UpdateSoundLoop(dt)
		end
	end
	
	function SpeakerHandler.GetLoopInfo(speaker): { Length: number, TimePlayed: number }
		if not speaker then
			error("[SpeakerHandler.GetLoopInfo]: No speaker provided")
		end
		
		local info = SpeakerHandler._LoopedSounds[speaker.GUID]
		
		if not info then
			return
		end
		
		return {
			Length = info.Length,
			TimePlayed = tick() - info.TimePlayed
		}
	end
	
	function SpeakerHandler.CreateSound(config: { Id: number, Pitch: number, Length: number, Speaker: any, RepeatCount: number, RepeatDelay: number } ) -- Psuedo sound object, kinda bad
		config.Pitch = config.Pitch or 1
		config.RepeatCount = config.RepeatCount or 1
		config.RepeatDelay = config.RepeatDelay or 0
		
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
			
			if sound._RepeatThread then
				coroutine.close(sound._RepeatThread)
				sound._RepeatThread = nil
			end
			
			sound._Speaker:Configure({Audio = sound.Id, Pitch = sound.Pitch})
			
			sound._RepeatThread = task.spawn(function()
				for i = 1, config.RepeatCount do
					sound._Speaker:Trigger()
					task.wait( (sound.Length or 0) + config.RepeatDelay )
				end
			end)
			
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
			
			if sound._RepeatThread then
				coroutine.close(sound._RepeatThread)
				sound._RepeatThread = nil
			end
			
			sound._OnCooldown = false
			SpeakerHandler.RemoveSpeakerFromLoop(sound._Speaker)
		end
		
		function sound:Loop()
			if not sound.Length then
				error("[SpeakerHandler.Sound]: Sound must have a length to be looped")
			end
			
			sound._Looped = true
			SpeakerHandler.LoopSound(sound.Id, sound.Length, sound.Pitch, sound._Speaker)
		end
		
		function sound:Destroy()
			if sound._Looped then
				SpeakerHandler.RemoveSpeakerFromLoop(sound._Speaker)
			end
			
			table.clear(sound)
		end
		
		return sound
	end
	
	return SpeakerHandler
end

WOS_MODULES.ScreenPlus = function()
	-- thingy that adds a few methods to screens
	
	-- Tables
	local SpecialProperties = { -- properties that don't arent readable / don't work / don't really exist
		"Parent",
		"Visible"
	}
	
	local function WrapElement(element, screen: Screen): ScreenElement
		local wrap = {}
		local valueTable = {}
		local mt = {}
	
		wrap.ClassName = "ScreenElement" -- This may cause some issues
		wrap.ElementClass = element.ClassName :: string
		wrap._Element = element
		wrap._Screen = screen
	
		function wrap:AddChild(child: ScreenElement?)
			if child.ClassName ~= "ScreenElement" then -- Temporary fix for the radar code
				--error("[ScreenPlus.Element:AddChild]: Provided child is not a ScreenPlus element.")
				wrap._Element:AddChild(child)
				return
			end
			
			child.Parent = wrap
		end
		
		function wrap:Clone(): ScreenElement
			local properties = table.clone(valueTable)
			local clone = wrap._Screen:CreateElement(wrap._Element.ClassName, properties)
			
			for _, v in ipairs(wrap._Screen:GetElementMany({ Parent = wrap })) do -- Deep copy
				v:Clone().Parent = clone
			end
			
			if wrap.Parent then
				clone.Parent = wrap.Parent
			end
			
			return clone
		end
		
		function wrap:ClearAllChildren()
			for _, v in wrap._Screen:GetElementMany({Parent = wrap}) do
				v:Destroy()
			end
		end
	
		function wrap:Destroy()
			wrap:ClearAllChildren()
			element:Destroy()
	
			local index = table.find(wrap._Screen._Elements, wrap)
			table.remove(screen._Elements, index)
			
			setmetatable(wrap, nil)
			table.clear(wrap)
			table.clear(valueTable)
		end
	
		mt.__newindex = function(_, index, newValue) -- TODO find a way to clean this up a bit
			valueTable[index] = newValue
			
			if index == "Parent" and typeof(newValue) == "table" then
				newValue._Element:AddChild(element)
			end
	
			if index == "Size" and not valueTable.Visible then
				return
			end
			
			if index == "Visible" then
				if newValue then
					element.Size = valueTable.Size
				else
					element.Size = UDim2.fromScale(0, 0)
				end
			end
			
			assert(newValue ~= valueTable, "bro what???")
	
			if element[index] ~= nil and not table.find(SpecialProperties, index) then
				element[index] = newValue
			end
		end
	
		mt.__index = function(_, index)
			assert(index ~= valueTable, "what the heck??? __index")
			
			if valueTable[index] ~= nil then
				return valueTable[index]
			else
				return element[index]
			end
		end
	
		setmetatable(wrap, mt)
		return wrap
	end
	
	local function ScreenPlus(object): Screen
		if not object then
			error("[ScreenPlus]: Provided value is not a screen")
		end
		
		local screen = setmetatable({}, { __index = object })
		
		screen.ClassName = "ScreenPlus"
		screen._Object = object
		screen._Elements = {}
		
		function screen:CreateElement(className: string, properties: { Parent: ScreenElement, Visible: boolean, [string]: any }): ScreenElement
			local removedProperties = {
				Visible = true
			}
			
			for index, value in properties do -- Remove special properties so the actual element doesnt error since they are invalid
				if table.find(SpecialProperties, index) then
					removedProperties[index] = value
					properties[index] = nil -- So there aren't any errors
				end
			end
			
			local element = screen._Object:CreateElement(className, properties)
			local wrapped = WrapElement(element, screen)
			
			for index, value in properties do
				wrapped[index] = value
			end
			
			for index, value in removedProperties do
				wrapped[index] = value
			end
	
			table.insert(screen._Elements, wrapped)
			return wrapped
		end
	
		function screen:GetElement(filter: {}): ScreenElement?
			if typeof(filter) ~= "table" then
				error("[Screen:GetElement]: A filter dict as an argument is required")
			end
	
			for _, element in ipairs(screen._Elements) do
				local isMatch = true
	
				for k, v in filter do
	
					if element[k] ~= v then
						isMatch = false
					end
				end
				
				if isMatch then
					return element
				end
			end
		end
	
		function screen:GetElementMany(filter: {} | nil): { ScreenElement }
			local elements = {}
	
			for _, element in ipairs(screen._Elements) do
				local isMatch = true
	
				if filter then
					for k, v in filter do
	
						if element[k] ~= v then
							isMatch = false
							break
						end
					end
				end
	
				if not isMatch then
					continue
				end
	
				table.insert(elements, element)
			end
	
			return elements
		end
	
		function screen:ClearElements()
	
			for _, element in screen._Elements do -- So they can be removed from the elements table.
				element:Destroy()
			end
	
			screen._Object:ClearElements()
		end
	
		return screen
	end
	
	export type Screen = typeof(ScreenPlus())
	export type ScreenElement =  {
		ClassName: "ScreenElement",
		Parent: ScreenElement,
		Visible: boolean
	
	} & typeof(WrapElement())
	
	return ScreenPlus
end

WOS_MODULES.FileHandler = function()
	-- Modules
	local ListLayout = require("ListLayoutV2")
	
	-- Tables
	local Commands = {}
	local CommandNames = {}
	local FileHandler = { StartDirectory = "OS", Directory = nil, Screen = nil, Keyboard = nil }
	
	local CommandLineLabels = {}
	
	FileHandler.FileTypes = {
		"txt",
		"img",
		"exe",
		"aud",
	}
	
	-- Variables
	local window
	local keyboardConnection
	
	-- Functions
	local function ClearCommandLine()
		for _, label in pairs(CommandLineLabels) do
			window.Layout:Remove(label, true)
		end
	end
	
	local function CommandLine(text, indentLevel, pathSpecify)
		if not text then
			return
		end
		
		if not window or window.Destroyed then
			return "No window!!!"
		end
		
		indentLevel =  indentLevel or 0
		local label = FileHandler.Screen:CreateElement("TextLabel", { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.07), Font = Enum.Font.SourceSans })
		
		text = string.rep("\t", indentLevel)..text
		
		if pathSpecify then
			text = "sweetOS"..">"..text
		end
		
		label.Text = text
	
		window:AddChild(label)
		table.insert(CommandLineLabels, label)
		return label
	end
	
	local function KeyboardInput(text: string, playerName: string)
		print("text inputted")
		if not window or window.Destroyed then
			keyboardConnection:Unbind()
			keyboardConnection = nil
			
			window = nil
			print("Window is gone")
			return
		end
		
		text = text:gsub("\n", "")
		CommandLine(text, nil, true)
	
		local arguments = text:split(" ")
		local commandName = arguments[1]:lower()
		table.remove(arguments, 1)
	
		if commandName:match("^%s*$") then
			return
		end
	
		local command = CommandNames[commandName]
	
		if not command then
			CommandLine(`Command {commandName} was not found`)
			CommandLine("", nil, true)
			return
		end
	
		if command.Tags then
			for index, argument in ipairs(command.Tags) do
				local argString = `{argument:lower()} %"(.+)"`
				local x, y = text:lower():find(argString) -- string.find so uppsercase letters can be added back later.
	
				if x then
					arguments[index] = text:sub(x + #argument + 2, y - 1) -- String.find is really stupid. plus 2 becuase of the equal and bracket.
				end
			end
		end
	
		local success, returned = pcall(command.Callback, arguments, table.concat(arguments, " "))
	
		if success then
			CommandLine(returned)
			print(returned)
		else
			print(returned)
			CommandLine("Error running command")
			CommandLine(returned)
			CommandLine("", nil, true)
		end
	
		CommandLine("", nil, true)
	end
	
	function FileHandler.GetPathInfo(path) -- Must be absolute path :sob:
		path = path:gsub("\\", "/") -- So backslashes work
		path = path:gsub("^/+", "")
		path = path:gsub("^"..FileHandler.StartDirectory, "")
		--path = path:gsub(" ", "")
		
		local hirearchy = string.split(path, "/")
		
		local parent
		local file = FileHandler.Directory[FileHandler.StartDirectory]
		local fileIndex: string
		
		if path:match("^%s*$") or #path == 0 then
			return {
				Data = file,
				Parent = file
			}
		end
		
		for _, fileName in ipairs(hirearchy) do
			if file[fileName] then
				parent = file
				file = file[fileName]
				fileIndex = fileName
			else
				return
			end
		end
		
		return {
			Data = file,
			Parent = parent,
			Name = fileIndex,
			Type = if typeof(file) == "table" then "Folder" else fileIndex:split(".")[2]
		}
	end
	
	function FileHandler.SetPathData(path, data)
		local split = string.split(path, "/")
	
		local parentName = split[#split - 1]
		local fileName = split[#split]
	
		table.remove(split, #split)
		local parentPath = table.concat(split, "/")
	
		local parentInfo = FileHandler.GetPathInfo(parentPath)
	
		if not parentInfo then
			print(`Path {parentPath} does not exist`)
			return
		end
	
		if typeof(parentInfo) ~= "table" then -- Not a folder
			print(`Folder {parentPath} does not exist`)
			return
		end
	
		local function validateData(data)
			if typeof(data) ~= "table" then
				local fileType = string.split(fileName, ".")[2]
	
				if not table.find(FileHandler.FileTypes, fileType) then
					error(`Invalid File type: {fileName}`)
				end
	
				return
			end
	
			for fileName, value in pairs(data) do
				local fileType = string.split(fileName, ".")[2]
	
				if typeof(value) == "table" then
					validateData(value)
					continue
				end
	
				if not table.find(FileHandler.FileTypes, fileType) then
					error(`Invalid File: {fileName}`)
				end
			end
		end
	
		if data ~= nil then
			validateData(data)
		end
	
		parentInfo.Data[fileName] = data
		return true
	end
	
	function FileHandler.ConnectToWindow(createdWindow)
		window = createdWindow
		
		local su, er = pcall(function()
			CommandLine("", nil, true)
			keyboardConnection = FileHandler.Keyboard:Connect("TextInputted", KeyboardInput)
		end)
		
		if not su then
			print(er)
		end
	end
	
	
	Commands.Mkdir = {
		Usages = {"makedirectory"},
		Callback = function(_, path)
			FileHandler.SetPathData(path, {})
			return `Created directory {path}`
		end,
	}
	
	Commands.Mkfile = {
		Usages = {"makefile"},
		Tags = {"-n"},
		Callback = function(args)
			local path = args[1]
			table.remove(args, 1)
			local data = table.concat(args, " ")
			
			local success = pcall(function()
				FileHandler.SetPathData(path, data)
			end)
			
			if success then
				return `New File --> {path}`
			else
				return "Failed to save file, Invalid file type or path does not exist"
			end
		end,
	}
	
	Commands.Dir = {
		Usages = {"ldir", "listdirectory"},
		Callback = function(_, path)
			local info = FileHandler.GetPathInfo(path)
			
			if not info or typeof(info) ~= "table" then
				return `Directory '{path}' was not found`
			end
			
			info = info.Data
			
			local split = path:split("/")
			local parent = split[#split]
			
			for name, v in pairs(info) do
				local fileType = if typeof(v) == "table" then "Directory" else "File"
				local text = `{parent} --> {name} --> {fileType}`
				CommandLine(text, 1)
			end
		end,
	}
	
	Commands.Data = {
		Callback = function(_, path)
			local info = FileHandler.GetPathInfo(path)
			
			if not info then
				return `{path} does not exist`
			end
	
			if typeof(info.Data) == "table" then
				return `Directory. Use dir {path}.`
			else
				return info.Data
			end
		end,
	}
	
	Commands.Cmds = {
		Usages = {"help"},
		Callback = function()
			
			for name, command in pairs(Commands) do
				CommandLine(name, 1)
			end
		end,
	}
	
	Commands.Cls = {
		Usages = {"clear", "clr"},
		Callback = ClearCommandLine
	}
	
	for mainName, command in pairs(Commands) do
		CommandNames[mainName:lower()] = command
	
		if command.Usages then
			for _, usage in pairs(command.Usages) do
				CommandNames[usage:lower()] = command
			end
		end
	end
	
	return FileHandler
end

WOS_MODULES.GridLayout = function()
	export type GridLayoutInfo = {
		Padding: UDim2,
		CellSize: UDim2,
		StartPosition: UDim2,
		FillDirection: Enum.FillDirection
	}
	
	local function GridLayout(parent, config: GridLayoutInfo)
		local self = {
			Parent = parent,
			_Children = {},
			_Config = config
		}
	
		local function scaleUdim2(udim2: UDim2)
			local absoluteSize = self.Parent.AbsoluteSize
	
			local scaleX = udim2.X.Scale + (udim2.X.Offset / absoluteSize.X)
			local scaleY = udim2.Y.Scale + (udim2.Y.Offset / absoluteSize.Y)
	
			return UDim2.fromScale(scaleX, scaleY)
		end
	
		if config.StartPosition then
			config.StartPosition = scaleUdim2(config.StartPosition)
		else
			config.StartPosition = UDim2.fromScale(0, 0)
		end
	
		config.CellSize = scaleUdim2(config.CellSize) -- Convert everything to scale. Easier to use to me because i suck
		config.Padding = scaleUdim2(config.Padding)
	
		function self:AddChild(child: GuiObject)
			child.Size = config.CellSize
			self.Parent:AddChild(child)
	
			local lastChild: GuiObject = self._Children[#self._Children]
			local position = config.StartPosition
	
			if lastChild then
				position = UDim2.fromScale(position.X.Scale, lastChild.Position.Y.Scale)
				local spaceLeft = lastChild.Position.X.Scale + config.CellSize.X.Scale + config.Padding.X.Scale + (config.CellSize.X.Scale / 2) -- Uhh this just works
	
				if spaceLeft < 1 then
					position = UDim2.fromScale(lastChild.Position.X.Scale + config.CellSize.X.Scale + config.Padding.X.Scale, lastChild.Position.Y.Scale)
				else
					position += UDim2.fromScale(0, config.CellSize.Y.Scale + config.Padding.Y.Scale)
				end
			end
	
			child.Position = position
			table.insert(self._Children, child)
		end
	
		function self:Refresh()
			config.CellSize = scaleUdim2(config.CellSize)
			config.Padding = scaleUdim2(config.Padding)
			
			local clone = table.clone(self._Children)
			self._Children = {}
	
			for _, v in ipairs(clone) do
				self:AddChild(v)
			end
		end
	
		function self:Remove(childIndex, destroyChild: boolean)
			local index = childIndex
	
			if typeof(childIndex) ~= "number" then
				index = table.find(self._Children, childIndex)
			end
	
			if not index then
				print(("[Grid Layout]: Child was not found. Cannot remove."))
				return
			end
	
			local child = self._Children[index]
			table.remove(self._Children, index)
	
			if destroyChild then
				child:Destroy()
			end
	
			self:Refresh()
		end
		
		function self:Destroy()
			table.clear(self)
		end
		
		return self
	end
	
	export type GridLayout = typeof(GridLayout())
	
	return GridLayout
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
	
	return function(config: { Time: number, Button: TextButton, Keyboard: any, InputText: string, DefaultText: string}, callback: (string, string) -> ())
		local button = config.Button
		local defaultText = config.DefaultText
	
		config.Keyboard = config.Keyboard or error("[InputButton]: No keyboard")
		button.MouseButton1Click:Connect(function()
			if ActiveInputs[config.Keyboard.GUID] then
				return
			end
			
			ActiveInputs[config.Keyboard.GUID] = true
			
			button.Text = config.InputText or "Input Keyboard"
	
			local text, playerName = GetKeyboardInput(config.Keyboard, config.Time or 6) -- yields
			
			if defaultText then
				button.Text = defaultText
			end
	
			if text then
				local success, errormsg = pcall(callback, text, playerName)
	
				if not success then
					print(`[InputButton]: error in callback:\n{errormsg}`)
				end
			end
			
			ActiveInputs[config.Keyboard.GUID] = false
		end)
	end
end

WOS_MODULES.WindowHandler = function()
	local WindowHandler = { -- Agony.
		Screen = GetPartFromPort(1, "Screen") or GetPartFromPort(1, "TouchScreen"),
		MoveWindows = true,
	}
	
	local Components = {
		WindowTemplate = function(Parent, windowType)
			local containerTypes = {
				Scroll = {"ScrollingFrame", { CanvasSize = UDim2.fromScale(0, 1), AutomaticCanvasSize = Enum.AutomaticSize.Y, BottomImage = "", ScrollBarImageColor3 = Color3.fromHex("#000000"), ScrollBarThickness = 3, TopImage = "", Active = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.9) }},
				Text = {"TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.89) }},
				Custom = {"Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.9) }}
			}
	
			local info = containerTypes[windowType] or containerTypes.Custom
	
			local windowTemplate = WindowHandler.Screen:CreateElement("TextButton", { Text = "", TextScaled = true, TextWrapped = true, AutoButtonColor = false, Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromHex("#505050"), BorderColor3 = Color3.fromHex("#323232"), BorderSizePixel = 2, Position = UDim2.fromScale(0.5, 0.5), Selectable = false, Size = UDim2.fromScale(0.6, 0.6) })
			local contentFrame = WindowHandler.Screen:CreateElement(info[1], info[2]) -- Content container
	
			local title = WindowHandler.Screen:CreateElement("TextLabel", { RichText = true, TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.fromScale(0.53, 0.1) })
			local titleUnderline = WindowHandler.Screen:CreateElement("Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#FFFFFF"), BorderSizePixel = 0, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.1) })
	
			local closeButton = WindowHandler.Screen:CreateElement("TextButton", { Text = "X", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.1, 0.1) })
			local minimizeButton = WindowHandler.Screen:CreateElement("TextButton", { RichText = true, Text = "-", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.8, 0), Size = UDim2.fromScale(0.1, 0.1) })
			local maximizeButton = WindowHandler.Screen:CreateElement("TextButton", { RichText = true, Text = "+", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.9, 0), Size = UDim2.fromScale(0.1, 0.1) })
			local background = WindowHandler.Screen:CreateElement("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 })
	
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
		Layout: any, -- ListLayout/GridLayout
		Parent: GuiObject,
		StartPosition: UDim2,
		
		BackgroundImage: any,
		BackgroundImageColor: Color3,
		BackgroundBrightenColor: Color3, -- For images than can't be recolored, or get dark when they are
		
		OverwriteIfExists: boolean
	}
	
	local Windows: { [string]: Window } = {}
	
	-- Functions
	local function CountKeys(tble)
		local count = 0
	
		for _ in pairs(tble) do
			count += 1
		end
	
		return count
	end
	
	-- Window Handler Functions
	function WindowHandler.Create(config: WindowConfig): Window
		if not WindowHandler.Screen then
			error("[WindowHandler]: No Screen was assigned")
		end
		
		if Windows[config.Name] then
			
			if config.OverwriteIfExists then -- If the self already exists
				Windows[config.Name]:Destroy()
			else
				return Windows[config.Name]
			end
		end
	
		config = config or error("[WindowHandler.Create]: No config provided")
		config.Color = config.Color or WindowHandler.DefaultConfig.Color
		config.Parent = config.Parent or WindowHandler.DefaultConfig.Parent
		config.WindowSize = config.WindowSize or UDim2.fromScale(0.6, 0.6)
		config.StartPosition = config.StartPosition or UDim2.fromScale(0.5, 0.5)
		
		if config.Text then
			config.Type = "Text"
		end
		
		local self = {
			ClassName = "WindowHandler.ScreenWindow",
			_Config = config,
			_Elements = Components.WindowTemplate(config.Parent or WindowHandler.DefaultConfig.Parent, config.Type),
			Max = false,
			Destroyed = false,
			Layout = config.Layout
		}
		
		if config.BackgroundImage then
			self._Elements.background.Image = config.BackgroundImage
			self._Elements.background.ImageColor3 = config.BackgroundImageColor or Color3.fromRGB(255, 255, 255)
			
			if config.BackgroundBrightenColor then
				local brighten = WindowHandler.Screen:CreateElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 0.5,
					BackgroundColor3 = config.BackgroundBrightenColor,
					ZIndex = 0
				})
				
				self._Elements.background:AddChild(brighten)
			end
		end
		
		local mainFrame = self._Elements.windowTemplate
		local contentContainer = self._Elements.contentFrame
		
		self._Elements.title.Text = config.Name
		mainFrame.Size = config.WindowSize
		mainFrame.Position = config.StartPosition
		mainFrame.ZIndex = CountKeys(Windows) + 1
		print("ZINDEX")
	
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
			if not WindowHandler.MoveWindows then
				return
			end
			
			if self.Max then
				return
			end
	
			for _, window in pairs(Windows) do
				if self == window then
					continue
				end
				
				local moved = false
	
				while self._Elements.windowTemplate.Position == window._Elements.windowTemplate.Position do
					mainFrame.Position += UDim2.fromScale(0.05, 0.05)
					moved = true
				end
				
				if moved then
					MoveOutOfWay()
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
			mainFrame.Position = config.StartPosition
			MoveOutOfWay()
		end
	
		function self:Destroy()
			self._Elements.windowTemplate:Destroy()
			self.Destroyed = true
			
			if self.Layout then
				self.Layout:Destroy()
			end
			
			Windows[config.Name] = nil
		end
	
		function self:AddChild(child)
			if self.Layout then -- list layout/grid layout
				self.Layout.Parent = contentContainer -- Solves recursive
				self.Layout:AddChild(child)
			else
				contentContainer:AddChild(child)
			end
		end
	
		MoveOutOfWay()
	
		mainFrame.MouseButton1Click:Connect(function()
			for _, self in pairs(Windows) do
				self._Elements.windowTemplate.ZIndex = 1
			end
	
			mainFrame.ZIndex = 2
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
		
		--setmetatable(self, {__index = contentContainer}) -- I feel like this will create more problems than it'll solve later on. (Grid layout)
		
		Windows[config.Name] = self
		return self
	end
	
	function WindowHandler.GetWindow(windowName: string)
		return Windows[windowName]
	end
	
	local defaultConfig: WindowConfig = {} -- Annoying. Type checks dont appear unless its made like this.
	WindowHandler.DefaultConfig = defaultConfig
	
	export type Window = typeof(WindowHandler.Create())
	
	return WindowHandler
end

--

-- Modules WHY ARE THERE SO MANY
local WindowHandler = require("WindowHandler")
local SpeakerHandler = require("SpeakerHandler")
local FileHandler = require("FileHandler")

local ListLayout = require("ListLayoutV2")
local GridLayout = require("GridLayout")

local StringUtil = require("StringUtility")
local TableUtil = require("TableUtility")

local ScreenPlus = require("ScreenPlus")
local InputButton = require("InputButton")
local PilotLua = require("PilotLua")

-- Objects
local Screen: ScreenPlus.Screen = ScreenPlus(GetPartFromPort(1, "TouchScreen"))
local Keyboard: PilotLua.Keyboard = GetPartFromPort(1, "Keyboard")
local Speaker: PilotLua.Speaker = GetPartFromPort(2, "Speaker")
local Disk: PilotLua.Disk = GetPartFromPort(2, "Disk")
local ThreadMicros: { [number]: PilotLua.Microcontroller } = GetPartsFromPort(3, "Microcontroller")

SpeakerHandler.DefaultSpeaker = Speaker

-- Screen Objects
Screen:ClearElements()

local background = Screen:CreateElement("ImageLabel", { Image = "http://www.roblox.com/asset/?id=13501991029", BackgroundColor3 = Color3.fromHex("#9FA1AC"), BorderColor3 = Color3.fromHex("#000000"), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) })
local taskbarFrame = Screen:CreateElement("ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.fromScale(1, 0), ScrollBarImageTransparency = 1, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#646464"), BackgroundTransparency = 0.3, BorderColor3 = Color3.fromHex("#000000"), BorderSizePixel = 0, ClipsDescendants = false, Position = UDim2.fromScale(0, 1), Selectable = false, Size = UDim2.fromScale(1, 0.15), SelectionGroup = false })
local windowContainer = Screen:CreateElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.85), ClipsDescendants = true })

background:AddChild(taskbarFrame)
background:AddChild(windowContainer)

-- Custom Screen Objects
local TaskbarListLayout = ListLayout(taskbarFrame, {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, -1)
})
local TaskbarGridLayout = GridLayout(windowContainer, {
	StartPosition = UDim2.fromScale(0.05, 0.05),
	CellSize = UDim2.fromScale(0.2, 0.2),
	Padding = UDim2.fromScale(0.05, 0.05)
})

local Components = {
	TaskManager_TaskInfo = function(Parent)
		local taskManager_TaskInfo = Screen:CreateElement("Frame", { BackgroundColor3 = Color3.fromHex("#3C3C3C"), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.15) })
		local taskName = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#FFFFFF"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Size = UDim2.fromScale(0.3, 1), Font = Enum.Font.SourceSans })
		local deleteTaskButton = Screen:CreateElement("TextButton", { Text = "Delete Task", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#C80000"), BorderSizePixel = 0, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.3, 1), Font = Enum.Font.SourceSans })
		taskManager_TaskInfo:AddChild(taskName)
		taskManager_TaskInfo:AddChild(deleteTaskButton)

		if Parent then Parent:AddChild(taskManager_TaskInfo) end
		return { taskManager_TaskInfo = taskManager_TaskInfo, taskName = taskName, deleteTaskButton = deleteTaskButton }
	end,

	Taskbar_Button = function(Parent, iconID)
		local iconButton = { Image = iconID, Active = false, BackgroundTransparency = 0.5, BorderColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 2, Selectable = false, Size = UDim2.fromScale(0.12, 1) }
		local textButton = { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = false, BackgroundTransparency = 0.5, BorderColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 2, Selectable = false, Size = UDim2.fromScale(0.3, 1) }

		local button = if iconID then Screen:CreateElement("ImageButton", iconButton) else Screen:CreateElement("TextButton", textButton)

		if Parent then Parent:AddChild(button) end
		return { button = button }
	end,

	PlayerCursor = function(Parent)
		local playerCursor = Screen:CreateElement("ImageLabel", { Image = "http://www.roblox.com/asset/?id=13768656219", ImageColor3 = Color3.fromHex("#4B974B"), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromScale(0.05, 0.05) })

		if Parent then Parent:AddChild(playerCursor) end
		return { playerCursor = playerCursor }
	end,

	FileExplorer_GridFile = function(Parent)
		local fileInfoContainer = Screen:CreateElement("TextButton", { Active = true, Text = "", BackgroundColor3 = Color3.fromHex("#FFFFFF"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Size = UDim2.fromOffset(100, 100) })
		local fileName = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.25), Font = Enum.Font.SourceSans })
		local fileIcon = Screen:CreateElement("ImageLabel", { ImageColor3 = Color3.fromHex("#C8C8C8"), ScaleType = Enum.ScaleType.Fit, Active = false, BackgroundTransparency = 1, Selectable = false, Size = UDim2.fromScale(1, 0.75) })
		fileInfoContainer:AddChild(fileName)
		fileInfoContainer:AddChild(fileIcon)

		if Parent then Parent:AddChild(fileInfoContainer) end
		return { fileIcon = fileIcon, fileInfoContainer = fileInfoContainer, fileName = fileName }
	end,
	
	FileExplorer_ListFile = function(Parent)
		local fileInfoContainer = Screen:CreateElement("TextButton", { Active = true, Text = "", TextScaled = true, TextWrapped = true, AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#FFFFFF"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Selectable = false, Size = UDim2.fromScale(1, 0.15) })
		local fileName = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0.2, 0), Size = UDim2.fromScale(0.25, 1), Font = Enum.Font.SourceSans })
		local fileIcon = Screen:CreateElement("ImageLabel", { Image = "http://www.roblox.com/asset/?id=697651751", ImageColor3 = Color3.fromHex("#C8C8C8"), ScaleType = Enum.ScaleType.Fit, BackgroundTransparency = 1, Size = UDim2.fromScale(0.15, 1) })
		local fileType = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.25, 1), Font = Enum.Font.SourceSans })
		local fileSize = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.2, 1), Font = Enum.Font.SourceSans })
		fileInfoContainer:AddChild(fileName)
		fileInfoContainer:AddChild(fileIcon)
		fileInfoContainer:AddChild(fileType)
		fileInfoContainer:AddChild(fileSize)
		
		if Parent then Parent:AddChild(fileInfoContainer) end
		return { fileInfoContainer = fileInfoContainer, fileType = fileType, fileName = fileName, fileIcon = fileIcon, fileSize = fileSize }
	end,
}

-- Tables
local OSConfig: {
	Accent: Color3,
	Wallpaper: string | number,
	PinnedFiles: { { string } }
} = Disk:Read("OSConfig")

local OSDirectory: {} = Disk:Read("OSDirectory")
local PlayerCursors = {}
local TaskbarInfos = {}

-- Micro tasks
local MicroTaskList: { [string]: { TaskName: string, Part: PilotLua.Microcontroller } } = {}
local ProcessResults = {}

-- File Explorer
local FileIcons = {
	["EmptyFolder"] = "http://www.roblox.com/asset/?id=697657018",
	["Folder"] = "http://www.roblox.com/asset/?id=697651751",
	["txt"] = "http://www.roblox.com/asset/?id=273954106",
	["img"] = "http://www.roblox.com/asset/?id=11496279085",
	["exe"] = "http://www.roblox.com/asset/?id=11348555035",
	["aud"] = "http://www.roblox.com/asset/?id=302250236",
}

local Sounds = {
	Error = SpeakerHandler.CreateSound({ Id = 9075457706, Pitch = 1.5, Length = 0.25, RepeatCount = 3 })
}

-- Constants
local PINNED_FILES_INDEX = 5

-- Functions
local function GetFileIcon(file)
	if typeof(file) == "table" then

		if TableUtil.CountKeys(file) > 0 then
			return "Folder", FileIcons.Folder
		else
			return "Folder", FileIcons.EmptyFolder
		end

	end

	local split = string.split(file, ".")
	return split[2], FileIcons[split[2]]
end

local function GetKeyboardInput(timeoutSeconds): (string?, string?)
	timeoutSeconds = timeoutSeconds or 3
	local timeWaited = 0

	local text, playerName

	local connection = Keyboard:Connect("TextInputted", function(inputText, inputPlayerName)
		text = inputText
		playerName = inputPlayerName
	end)

	while timeWaited < timeoutSeconds and not (text and playerName) do
		timeWaited += task.wait()
	end
	
	connection:Unbind()

	if not text then
		print("Ran out of time!")
		return
	end
	
	text = string.gsub(text, "\n+$")
	return text, playerName
end

local function WindowInput(prompt: string?, timeoutSeconds: number)
	local window = WindowHandler.Create({
		Text = prompt or "Input",
		Name = "Input",
		WindowHandler.DefaultConfig.Color,
		OverwriteIfExists = true
	})
	
	task.delay(timeoutSeconds, function() -- So even if the thread micro turns off, the window will be destroyed.
		if not window.Destroyed then
			window:Destroy()
		end
	end)
	
	local result = { GetKeyboardInput(timeoutSeconds) }
	
	window:Destroy()
	return table.unpack(result)
end

local function CreateTaskbarButton(name: string, config: {Image: string | number, Text: string, Type: "List" | "Grid", WindowConfig: WindowHandler.WindowConfig, Callback: (window: WindowHandler.Window, ...any) -> () })
	if not config.Type then
		config.Type = "List"
	end	
	
	local parent
	
	if config.Type == 'List' then
		parent = TaskbarListLayout
	elseif config.Type == "Grid" then
		parent = TaskbarGridLayout
	else
		error("[CreateTaskbarButton]: Invalid button type.")
	end

	local info = Components.Taskbar_Button(parent, config.Image)

	info.button.Name = name
	info.button.Text = config.Text or name

	info.button.BackgroundColor3 = OSConfig.Accent
	info.button.MouseButton1Click:Connect(function()
		local window: WindowHandler.Window?

		if config.WindowConfig then
			window = WindowHandler.GetWindow(config.WindowConfig.Name)

			if window then
				window:Destroy()
				window = nil
				return
			else
				window = WindowHandler.Create(config.WindowConfig)
			end
		end

		if config.Callback then
			local success, returned = pcall(config.Callback, window)

			if not success then
				SpeakerHandler.Chat("Error in taskbar callback")
				print(returned)
			end
		end
	end)
	
	TaskbarInfos[name] = config
	return info
end

-- TASKS
local function GetUnusedMicro(): PilotLua.Microcontroller?
	for _, v in ipairs(ThreadMicros) do
		if not MicroTaskList[v.GUID] then
			return v
		end
	end
end

local function StopProcess(taskName)
	for i, info in pairs(MicroTaskList) do

		if info.Task == taskName then
			MicroTaskList[i] = nil
			
			local polysilicon = GetPartFromPort(info.Part, "Polysilicon")
			local polyPort = GetPartFromPort(polysilicon, "Port")

			info.Part:Configure({Code = [[error("No task")]]})

			polysilicon:Configure({PolysiliconMode = 1})
			TriggerPort(polyPort)
		end
	end
end

local function ProcessResult(taskName, resultInfo)
	local success = resultInfo[1]
	local windowConfig: WindowHandler.WindowConfig = {Name = taskName, OverwriteIfExists = true}

	if success then
		windowConfig.Text = resultInfo[2] or "Task has completed"
	else
		windowConfig.Text = "An error has occured"
		windowConfig.Color = BrickColor.new("Bright red").Color
		print(resultInfo[2])
		Sounds.Error:Play()
	end
	
	WindowHandler.Create(windowConfig)
	task.wait(0.5)
	StopProcess(taskName)
end

local function RunStringCode(micro, codeString)
	local polysilicon = GetPartFromPort(micro, "Polysilicon") or error("Microcontroller has no polysilicon")
	local polyPort = GetPartFromPort(polysilicon, "Port") or error("Microcontroller has no Polysilicon port")

	polysilicon:Configure({PolysiliconMode = 1})
	TriggerPort(polyPort)
	
	micro:Configure({Code = codeString})

	polysilicon:Configure({PolysiliconMode = 0})
	TriggerPort(polyPort)
end

local function CreateProcess(taskName, codeToRun: string, environmentVariables: {}): boolean
	environmentVariables = environmentVariables or {}
	local micro = GetUnusedMicro()
	
	if not micro then
		print(`No microcontrollers left for task '{taskName}'`)
		return
	end
	
	environmentVariables.OSLibrary = Disk:Read("OSLibrary")
	environmentVariables.ProcessResults = ProcessResults
	print(ProcessResults)
	print(JSONEncode(ProcessResults))
	
	local lines = setmetatable({}, {__index = table})

	lines:insert('local envDisk = GetPartFromPort(1, "Disk")')

	for key, value in pairs(environmentVariables) do
		Disk:Write(key, value)
		lines:insert(string.format("local %s = envDisk:Read(%q)\n", key, key))
	end

	lines:insert("local function main()")

	for _, line in ipairs(codeToRun:split("\n")) do
		lines:insert("\t"..line)
	end

	lines:insert("end\n")
	lines:insert("local response = { pcall(main) }")
	lines:insert( string.format("ProcessResults[%q] = response", taskName) )
	
	local snippet = lines:concat("\n")
	
	MicroTaskList[micro.GUID] = {Part = micro, Task = taskName}
	
	RunStringCode(micro, snippet)
	return true
end

local function CreateProcessFunction(taskName, targetFunc: () -> ()): boolean
	local env = { TargetFunc = targetFunc }
	
	local lines = setmetatable({}, {__index = table})
	lines:insert("return TargetFunc()")
	
	return CreateProcess(taskName, table.concat(lines, "\n"), env)
end

-- File Explorer
local function OpenFile(path)
	local info = FileHandler.GetPathInfo(path)

	if not info then
		print(`Path {path} does not exist`)
		return
	end
	
	if typeof(info.Data) == "table" then
		local info = TaskbarInfos["File Explorer"]
		info.WindowConfig.OverwriteIfExists = true
		
		local window = WindowHandler.Create(info.WindowConfig)
		
		info.Callback(window, path)
		return
	end

	local fileName = info.Name
	local fileType = info.Name:split(".")[2]
	local data = info.Data

	local windowConfig: WindowHandler.WindowConfig = {
		Name = `File: {fileName}`
	}

	if fileType == "txt" then -- ELSEIF!!! :carbonmonoxide:
		windowConfig.Text = data
	elseif fileType == "img" then
		windowConfig.Type = "Custom"
		windowConfig.BackgroundImage = data
	elseif fileType == "exe" then
		local micro = GetUnusedMicro()

		if micro then
			if data:match("^http") then
				RunStringCode(micro, data)
			else
				CreateProcess(fileName, data, {})
			end
			
			windowConfig.Text = "File Executing..."
		else
			windowConfig.Text = "No microcontrollers available. Please stop some tasks."
		end

	elseif fileType == "aud" then
		local id = string.split(data, " ")[1]
		local length = tonumber(string.match(data, "length:(%S+)"))
		local pitch = tonumber(string.match(data, "pitch:(%S+)")) or 1

		if length then
			SpeakerHandler.LoopSound(id, length, pitch)
		else
			SpeakerHandler.PlaySound(id, pitch, 0.5)
		end

		windowConfig.Text = `Looped: {length ~= nil}\n\nPitch:{pitch}`
	end

	WindowHandler.Create(windowConfig)
end

local function LoadPinnedFiles()
	local shortcuts = {}

	for i, info in ipairs(OSConfig.PinnedFiles) do -- Array so it's always in order.
		local fileName = info[1]
		local filePath = info[2]

		local pathInfo = FileHandler.GetPathInfo(filePath)

		if shortcuts[filePath] or not pathInfo or Screen:GetElement({ Name = fileName }) then
			table.remove(shortcuts, i)
			continue
		end

		local label = CreateTaskbarButton(fileName, {
			Image = if pathInfo.Type == "img" then pathInfo.Data else nil,
			Callback = function()
				OpenFile(filePath)
			end,
		})
		
		-- This horrid crap to insert at a specific place.
		table.remove(TaskbarListLayout._Children, table.find(TaskbarListLayout._Children, label.button))
		table.insert(TaskbarListLayout._Children, PINNED_FILES_INDEX, label.button)
		
		TaskbarListLayout:Refresh()
		shortcuts[filePath] = true
	end
end

-- Setup
if not OSConfig then
	OSConfig = {
		Accent = BrickColor.new("Bright green").Color,
		Wallpaper = "http://www.roblox.com/asset/?id=13501991029",
		PinnedFiles = {}
	}

	Disk:Write("OSConfig", OSConfig)
end

if not OSDirectory then
	OSDirectory = {
		["OS"] = {
			["images"] = { ["mug.img"] = "http://www.roblox.com/asset/?id=7766066072" },
			["text-files"] = { ["hello.txt"] = "this is some text" },
			["executable-files"] = {
				["loop.exe"] = "while true do task.wait() end",
				["calculate.exe"] = "return `1 + 9 is {1 + 9}`",
			},

			["audio"] = {
				["engine.aud"] = "6667206702 length:2.763",
				["pitch-engine.aud"] = "6667206702 length:2.763 pitch:1.5",
				["quiz.aud"] = "9042796147 length:197.982",
				["Synthwar.aud"] = "4580911200",
				["SynthBetter.aud"] = "4580911200 pitch:1.15",
				["DISTANT.aud"] = "4611202823 pitch:1.15",
				["blade.aud"] = "10951049295",
				["Climber.aud"] = "10951047950",
				["tune.aud"] = "1846897737"
			},
		}
	}

	Disk:Write("OSDirectory", OSDirectory)
end

WindowHandler.Screen = Screen
WindowHandler.DefaultConfig = {
	Parent = windowContainer,
	Color = OSConfig.Accent
}

FileHandler.StartDirectory = "OS"
FileHandler.Directory = OSDirectory

FileHandler.Screen = Screen
FileHandler.Disk = Disk
FileHandler.Keyboard = Keyboard

background.Image = OSConfig.Wallpaper

CreateTaskbarButton("Settings", {
	Image = OSConfig.Wallpaper,
	WindowConfig = {
		Name = "SweetOS",
		Type = "Scroll",
		BackgroundImage = "http://www.roblox.com/asset/?id=3899340539",
		BackgroundBrightenColor = OSConfig.Accent,
	},
	Callback = function(window)
		window:Maximize()

		local settingsNotice = Screen:CreateElement("TextLabel", { Text = "Settings May require a restart*", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.1), Font = Enum.Font.SourceSans })
		local appearanceTitle = Screen:CreateElement("TextLabel", { Text = "Appearance", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.2), Size = UDim2.fromScale(0.3, 0.1), Font = Enum.Font.SourceSans })
		local accentButton = Screen:CreateElement("TextButton", { Text = "Accent", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.35), Size = UDim2.fromScale(0.4, 0.1), Font = Enum.Font.SourceSans })
		local accentValue = Screen:CreateElement("Frame", { Active = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 0, Position = UDim2.fromScale(1, 0.35), Selectable = true, Size = UDim2.fromScale(0.5, 0.1) })
		local wallpaperButton = Screen:CreateElement("TextButton", { Text = "Wallpaper", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.525, 5), Size = UDim2.fromScale(0.4, 0.1), Font = Enum.Font.SourceSans })
		local wallpaperValue = Screen:CreateElement("ImageLabel", { Active = true, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#323232"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 0, Position = UDim2.fromScale(0.7, 0.5), Selectable = true, Size = UDim2.fromScale(0.2, 0.2) })

		window:AddChild(settingsNotice)
		window:AddChild(appearanceTitle)
		window:AddChild(accentButton)
		window:AddChild(accentValue)
		window:AddChild(wallpaperButton)
		window:AddChild(wallpaperValue)

		accentValue.BackgroundColor3 = OSConfig.Accent
		wallpaperValue.Image = OSConfig.Wallpaper

		InputButton({ Button = accentButton, InputText = "Input Color3", Keyboard = Keyboard }, function(text)
			local oldColor = OSConfig.Accent
			local color = StringUtil.StringToColor3RGB(text)
			
			for _, v in Screen:GetElementMany({ BackgroundColor3 = oldColor }) do
				v.BackgroundColor3 = color
			end

			OSConfig.Accent = color
			WindowHandler.DefaultConfig.Color = color
		end)

		InputButton({ Button = wallpaperButton, InputText = "Input Image ID", Keyboard = Keyboard }, function(text)
			OSConfig.Wallpaper = text
			wallpaperValue.Image = text
			background.Image = text
		end)
	end,
})

CreateTaskbarButton("Command Prompt", {
	WindowConfig = {
		Name = "Command Prompt",
		Color = Color3.fromRGB(30, 30, 30),
		Type = "Scroll",
	},

	Callback = function(window)
		window.Layout = ListLayout(nil, {})
		FileHandler.ConnectToWindow(window)
	end,
})

CreateTaskbarButton("File Explorer", {
	WindowConfig = {
		Name = "File Explorer",
		Type = "Custom",
	},
	Callback = function(window, startPath: string?)
		local filePathLabel = Screen:CreateElement("TextButton", { Text = "OS", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#FFFFFF"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.1), Font = Enum.Font.SourceSans })
		local backButton = Screen:CreateElement("TextButton", { Text = "Back", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderColor3 = Color3.fromHex("#000000"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 3, Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(0.2, 0.1), Font = Enum.Font.SourceSans })
		local createFile = Screen:CreateElement("TextButton", { Text = "Create File", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderColor3 = Color3.fromHex("#000000"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 3, Position = UDim2.fromScale(0.2, 0.1), Size = UDim2.fromScale(0.2, 0.1), Font = Enum.Font.SourceSans })
		local refreshButton = Screen:CreateElement("ImageButton", { Image = "http://www.roblox.com/asset/?id=13492317101", ImageColor3 = Color3.fromHex("#0989CF"), ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderColor3 = Color3.fromHex("#000000"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 3, Position = UDim2.fromScale(1, 0.1), Size = UDim2.fromScale(0.2, 0.1) })
		local viewModeButton = Screen:CreateElement("TextButton", { Text = "Grid/List", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderColor3 = Color3.fromHex("#000000"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 3, Position = UDim2.fromScale(0.4, 0.1), Size = UDim2.fromScale(0.2, 0.1), Font = Enum.Font.SourceSans })
		local propertiesButton = Screen:CreateElement("TextButton", { Text = "Properties", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextTransparency = 0.5, TextWrapped = true, BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderColor3 = Color3.fromHex("#000000"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 3, Position = UDim2.fromScale(0.6, 0.1), Size = UDim2.fromScale(0.2, 0.1), Font = Enum.Font.SourceSans })
		local fileListContainer: ScrollingFrame = Screen:CreateElement("ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.fromScale(0, 1), ScrollBarImageColor3 = Color3.fromHex("#000000"), ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y, Active = true, AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.8) })
		
		window:AddChild(filePathLabel)
		window:AddChild(backButton)
		window:AddChild(createFile)
		window:AddChild(refreshButton)
		window:AddChild(viewModeButton)
		window:AddChild(propertiesButton)
		window:AddChild(fileListContainer)
		
		local fileLayout: GridLayout.GridLayout | ListLayout.ListLayout

		local currentPath = startPath or "/"
		local selectedFile
		
		local viewModes = {
			"Grid",
			"List",
		}
		
		local viewMode: "Grid" | "List" = "Grid"
		
		local function viewFolder(path)
			local su, er = pcall(function()
				path = path:gsub("^/+", ""):gsub("/+", "/")
				currentPath = path
				fileListContainer.CanvasPosition = Vector2.new(0, 0)
				propertiesButton.TextTransparency = 0.5

				for _, v in Screen:GetElementMany({ Parent = fileListContainer }) do
					fileLayout:Remove(v, true)
				end

				if viewMode == "List" then
					local key = Components.FileExplorer_ListFile(fileLayout)

					key.fileIcon.Image = FileIcons.EmptyFolder
					key.fileName.Text = "File Name"
					key.fileSize.Text = "File Size"
					key.fileType.Text = "File Type"
				end

				local info = FileHandler.GetPathInfo(path)

				for fileName, data in pairs(info.Data) do
					local fileType, icon

					if typeof(data) == "table" then
						fileType, icon = GetFileIcon(data)
					else
						fileType, icon = GetFileIcon(fileName)
					end

					if fileType == "img" then
						icon = data
					end

					local label

					if viewMode == "Grid" then
						label = Components.FileExplorer_GridFile(fileLayout)
					elseif viewMode == "List" then
						label = Components.FileExplorer_ListFile(fileLayout)

						--local fileName = Screen:CreateElement("TextLabel", { Text = "Some folder", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0.2, 0), Size = UDim2.fromScale(0.25, 1), Font = Enum.Font.SourceSans })
						--local fileIcon = Screen:CreateElement("ImageLabel", { Image = "http://www.roblox.com/asset/?id=697651751", ImageColor3 = Color3.fromHex("#C8C8C8"), ScaleType = Enum.ScaleType.Fit, BackgroundTransparency = 1, Size = UDim2.fromScale(0.15, 1) })
						--local fileType = Screen:CreateElement("TextLabel", { Text = "Folder", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.25, 1), Font = Enum.Font.SourceSans })
						--local fileSize 

						label.fileType.Text = fileType
						label.fileSize.Text = #(if typeof(data) ~= "table" then tostring(data) else JSONEncode(data)).." char"
					end

					label.fileName.Text = fileName
					label.fileIcon.Image = icon

					label.fileInfoContainer.MouseButton1Click:Connect(function()
						if selectedFile then
							selectedFile.label.fileInfoContainer.BackgroundTransparency = 0.9

							if selectedFile.label == label then -- Open the file or whatever

								if typeof(data) == "table" then
									viewFolder(path.."/"..fileName)
								else
									OpenFile(path.."/"..fileName)
								end

								selectedFile = nil
								propertiesButton.TextTransparency = 0.5
								return
							end
						end

						label.fileInfoContainer.BackgroundTransparency = 0.7
						propertiesButton.TextTransparency = 0

						selectedFile = {
							label = label,
							name = fileName,
							data = data,
							icon = icon,
							path = path.."/"..fileName,
							fileType = FileHandler.GetPathInfo(path.."/"..fileName).Type
						}
					end)
				end

				filePathLabel.Text = FileHandler.StartDirectory.."/"..currentPath
			end)
			
			if not su then
				print(er)
			end
		end
		
		local function updateLayout()
			if fileLayout then
				for _, v in Screen:GetElementMany({ Parent = fileListContainer }) do
					fileLayout:Remove(v, true)
				end

				fileLayout:Destroy()
				fileLayout = nil
			end
			
			if viewMode == "Grid" then
				fileLayout = GridLayout(fileListContainer, {
					Padding = UDim2.fromScale(0.1, 0.1),
					CellSize = UDim2.fromScale(0.2, 0.3),
					StartPosition = UDim2.fromScale(0.1, 0.05)
				})
			elseif viewMode == "List" then
				fileLayout = ListLayout(fileListContainer, {
					StartPosition = UDim.new(0, 0),
					Padding = UDim.new(0.05)
				})
			end
		end
		
		refreshButton.MouseButton1Click:Connect(function()
			viewFolder(currentPath)
		end)

		backButton.MouseButton1Click:Connect(function()
			local split = string.split(currentPath, "/")
			table.remove(split, #split)
			viewFolder(table.concat(split, "/"))
		end)
		
		viewModeButton.MouseButton1Click:Connect(function()
			local newIndex = table.find(viewModes, viewMode) + 1

			if newIndex > #viewModes then
				newIndex = 1
			end

			viewMode = viewModes[newIndex]
			viewModeButton.Text = viewMode
			
			updateLayout()
			viewFolder(currentPath)
		end)
		
		createFile.MouseButton1Click:Connect(function()
			local su, er = pcall(function()
				local window = WindowHandler.Create({
					Name = "Create File",
					Type = "Custom",
					OverwriteIfExists = true,
				})

				local fileNameButton = Screen:CreateElement("TextButton", { Text = "Sample", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.055), Size = UDim2.fromScale(1, 0.08), Font = Enum.Font.SourceSans })
				local fileNameLabel = Screen:CreateElement("TextLabel", { Text = "File Name", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#646464"), BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, -0.7), Selectable = true, Size = UDim2.fromScale(0.5, 0.7), Font = Enum.Font.SourceSans })
				local filePathButton = Screen:CreateElement("TextButton", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(1, 0.08), Font = Enum.Font.SourceSans })
				local filePathLabel = Screen:CreateElement("TextLabel", { Text = "File Path", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#646464"), BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, -0.7), Selectable = true, Size = UDim2.fromScale(0.5, 0.7), Font = Enum.Font.SourceSans })
				local fileTypeButton = Screen:CreateElement("TextButton", { Text = "Type:", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromScale(1, 0.08), Font = Enum.Font.SourceSans })
				local fileTypesLabel = Screen:CreateElement("TextLabel", { Text = "(img, exe, txt, folder)", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 1), Selectable = true, Size = UDim2.fromScale(0.5, 1), Font = Enum.Font.SourceSans })
				local fileTypeLabel = Screen:CreateElement("TextLabel", { Text = "File Type", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#646464"), BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, -0.7), Selectable = true, Size = UDim2.fromScale(0.5, 0.7), Font = Enum.Font.SourceSans })
				local createFileButton = Screen:CreateElement("TextButton", { Text = "Create File", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.5, 0.1), Font = Enum.Font.SourceSans })
				local fileDataButton = Screen:CreateElement("TextButton", { Text = "Data:", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#464646"), BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(1, 0.08), Font = Enum.Font.SourceSans })
				local fileDataLabel = Screen:CreateElement("TextLabel", { Text = "File Data", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromHex("#646464"), BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, -0.7), Selectable = true, Size = UDim2.fromScale(0.5, 0.7), Font = Enum.Font.SourceSans })
				local resultLabel = Screen:CreateElement("TextLabel", { Text = "", TextColor3 = Color3.fromHex("#FF0000"), TextScaled = true, TextWrapped = true, Active = true, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 1), Selectable = true, Size = UDim2.fromScale(0.5, 1), Font = Enum.Font.SourceSans })

				window:AddChild(fileNameButton)
				fileNameButton:AddChild(fileNameLabel)

				window:AddChild(filePathButton)
				filePathButton:AddChild(filePathLabel)

				window:AddChild(fileTypeButton)
				fileTypeButton:AddChild(fileTypesLabel)
				fileTypeButton:AddChild(fileTypeLabel)

				window:AddChild(createFileButton)

				window:AddChild(fileDataButton)
				fileDataButton:AddChild(fileDataLabel)
				fileDataButton:AddChild(resultLabel)

				local data = {
					Path = currentPath,
					Name = nil,
					Type = nil,
					Data = nil
				}
				
				filePathButton.Text = currentPath
				fileTypesLabel.Text = `(folder, {table.concat(FileHandler.FileTypes, ", ")})`

				InputButton({ Button = fileNameButton, InputText = "Enter File Name", Keyboard = Keyboard }, function(text)
					data.Name = text
					fileNameButton.Text = text
				end)

				InputButton({ Button = filePathButton, InputText = "Enter File Path", Keyboard = Keyboard }, function(text)
					local folder = FileHandler.GetPathInfo(text)

					if not folder then
						print("Invalid path")
						filePathButton.Text = "Invalid Path"
						return
					end
					
					data.Path = text
					filePathButton.Text = text
				end)

				InputButton({ Button = fileTypeButton, InputText = "Enter File Type", Keyboard = Keyboard }, function(text)
					if not table.find(FileHandler.FileTypes, text:lower()) and text:lower() ~= "folder" then
						fileTypeButton.Text = "Invalid File Type"
						data.Type = nil
						return
					end
					
					if text:lower() == "folder" then
						data.Data = {}
					end
					
					data.Type = text
					fileTypeButton.Text = text
				end)
				
				InputButton({ Button = fileDataButton, InputText = "Enter Data", Keyboard = Keyboard }, function(text)
					if data.Type == "folder" then
						return
					end
					
					data.Data = text
					fileDataButton.Text = text
				end)
				
				createFileButton.MouseButton1Click:Connect(function()
					local su, er = pcall(function()
						resultLabel.TextColor3 = Color3.fromRGB(200, 0, 0)
						resultLabel.Text = ""

						if not data.Name then
							resultLabel.Text = "No file name"
							return
						end

						if not data.Path then
							resultLabel.Text = "No file path"
							return
						end

						if not data.Type then
							resultLabel.Text = "No file type"
							return
						end

						if not data.Data then
							resultLabel.Text = "No file data"
							return
						end
						
						local pathString = `{data.Path}/{data.Name}`
						
						if typeof(data.Data) ~= "table" then
							pathString..=  "."..data.Type
						end

						FileHandler.SetPathData(pathString, data.Data)
						resultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
						resultLabel.Text = "Successfully Created File"
						
						viewFolder(currentPath)
					end)
					
					if not su then
						print(er)
					end
				end)
			end)
			
			if not su then
				print(er)
			end
		end)
		
		propertiesButton.MouseButton1Click:Connect(function()
			if not selectedFile then
				return
			end
			
			local currentFile = selectedFile
			
			local window = WindowHandler.Create({
				Name = `Properties: {selectedFile.name}`,
				Type = "Custom"
			})
			
			local fileIcon = Screen:CreateElement("ImageLabel", { Image = "http://www.roblox.com/asset/?id=697651751", BackgroundTransparency = 1, Size = UDim2.fromScale(0.25, 0.25) })
			local fileNameLabel = Screen:CreateElement("TextLabel", { RichText = true, TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.7, 0.15), Font = Enum.Font.SourceSans })
			local fileTypeLabel = Screen:CreateElement("TextLabel", { Text = "Type:", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(0.2, 0.1), Font = Enum.Font.SourceSans })
			local fileTypeValue = Screen:CreateElement("TextLabel", { Text = "img", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(1, 1), Font = Enum.Font.SourceSans })
			local fileSizeLabel = Screen:CreateElement("TextLabel", { Text = "Size (characters):", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(0.3, 0.15), Font = Enum.Font.SourceSans })
			local fileSizeValue = Screen:CreateElement("TextLabel", { Text = "2000", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(1, 1), Font = Enum.Font.SourceSans })
			local fileContainLabel = Screen:CreateElement("TextLabel", { Text = "Contains:", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.65), Size = UDim2.fromScale(0.3, 0.15), Font = Enum.Font.SourceSans })
			local fileContain_FolderCount = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromScale(1.1, 0), Size = UDim2.fromScale(1, 0.4), Font = Enum.Font.SourceSans })
			local fileContain_FileCount = Screen:CreateElement("TextLabel", { TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(1.1, 1), Size = UDim2.fromScale(1, 0.4), Font = Enum.Font.SourceSans })
			
			local pinButton = Screen:CreateElement("TextButton", { TextColor3 = Color3.fromHex("#000000"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#CDCDCD"), BorderColor3 = Color3.fromHex("#646464"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 2, Position = UDim2.fromScale(0, 1), Size = UDim2.new(0.3, 0, 0, 50), Font = Enum.Font.SourceSans })
			local deleteButton = Screen:CreateElement("TextButton", { Text = "Delete File", TextColor3 = Color3.fromHex("#C4281C"), TextScaled = true, TextWrapped = true, AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromHex("#CDCDCD"), BorderColor3 = Color3.fromHex("#646464"), BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 2, Position = UDim2.fromScale(0.35, 1), Size = UDim2.new(0.3, 0, 0, 50), Font = Enum.Font.SourceSans })
			
			window:AddChild(fileIcon)
			window:AddChild(fileNameLabel)
			
			window:AddChild(fileTypeLabel)
			window:AddChild(fileSizeLabel)
			window:AddChild(fileContainLabel)
			window:AddChild(pinButton)
			window:AddChild(deleteButton)
			
			fileTypeLabel:AddChild(fileTypeValue)
			fileSizeLabel:AddChild(fileSizeValue)

			fileContainLabel:AddChild(fileContain_FolderCount)
			fileContainLabel:AddChild(fileContain_FileCount)

			fileIcon.Image = currentFile.icon
			fileNameLabel.Text = `<u>{currentFile.name}</u>`
			
			fileTypeValue.Text = currentFile.fileType
			fileSizeValue.Text = #(if typeof(currentFile.data) == "table" then JSONEncode(currentFile.data) else currentFile.data)
			
			local folderCount = 0
			local fileCount = 0
			
			if typeof(currentFile.data) == "table" then
				
				for _, v in pairs(currentFile.data) do
					
					if typeof(v) == "table" then
						folderCount += 1
					else
						fileCount += 1
					end
				end
			end
			
			fileContain_FolderCount.Text = `{folderCount} folder{if folderCount > 0 then "s" else "" }`
			fileContain_FileCount.Text = `{fileCount} file{if fileCount > 0 then "s" else "" }`
			
			local isPinned = false
			local pinIndex
			
			for i, info in pairs(OSConfig.PinnedFiles) do
				if info[2] == currentFile.path then
					isPinned = true
					pinIndex = i
					break
				end
			end
			
			pinButton.Text = if not isPinned then "Pin to taskbar" else "Unpin from taskbar"
			
			--if type(currentFile.data) == "table" then
			--	pinButton.TextTransparency = 0.5
			--	pinButton.Text = "Cannot pin folders"
			--end
			
			pinButton.MouseButton1Click:Connect(function()
				if not currentPath then
					return
				end
				
				if not isPinned then
					table.insert(OSConfig.PinnedFiles, { currentFile.name, currentFile.path })
					
					pinIndex = #OSConfig.PinnedFiles
					pinButton.Text = "Unpin from taskbar"
				else
					table.remove(OSConfig.PinnedFiles, pinIndex)
					pinButton.Text = "Pin to taskbar"
					
					local element = Screen:GetElement({ Name = currentFile.name })
					
					if element then
						TaskbarListLayout:Remove(element, true)
					end
				end
				
				LoadPinnedFiles()
				isPinned = not isPinned
			end)
			
			deleteButton.MouseButton1Click:Connect(function()
				FileHandler.SetPathData(currentFile.path, nil)
				deleteButton.Text = "File deleted"

				local element = Screen:GetElement({ Name = currentFile.name })

				if element then
					TaskbarListLayout:Remove(element, true)
				end
				
				currentFile = nil
				viewFolder(currentPath)
			end)
		end)
		
		updateLayout()
		viewFolder(currentPath)
	end
})

CreateTaskbarButton("Processes", {
	WindowConfig = {
		Name = "Task Manager",
		Type = "Custom"
	},
	
	Callback = function(window)
		local threadInfoButton = Screen:CreateElement("TextButton", { Text = "Info", TextColor3 = Color3.fromHex("#FFFFFF"), TextScaled = true, TextWrapped = true, Active = false, AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = Color3.fromHex("#323232"), BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = UDim2.fromScale(1, 1), Selectable = false, Size = UDim2.fromScale(0.3, 0.1), Font = Enum.Font.SourceSans })
		local taskListFrame = Screen:CreateElement("ScrollingFrame", { AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.fromScale(0, 1), ScrollBarImageColor3 = Color3.fromHex("#000000"), ScrollBarThickness = 0, Active = true, AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.9), Size = UDim2.fromScale(1, 0.9) })

		window:AddChild(threadInfoButton)
		window:AddChild(taskListFrame)
		
		local taskListLayout = ListLayout(taskListFrame, {
			Padding = UDim.new(0.05, 0),
			StartPosition = UDim.new(0.1, 0)
		})
		
		for _, info in pairs(MicroTaskList) do
			local label = Components.TaskManager_TaskInfo(taskListLayout)
			label.taskName.Text = StringUtil.SplitTitleCaps(info.Task)
			
			label.deleteTaskButton.MouseButton1Click:Connect(function()
				local su, er = pcall(function()
					StopProcess(info.Task)
					taskListLayout:Remove(label.taskManager_TaskInfo, true)
				end)
				
				if not su then
					print(er)
				end
			end)
		end
		
		threadInfoButton.MouseButton1Click:Connect(function()
			WindowHandler.Create({
				Name = "Info",
				Text = `{#ThreadMicros} cores\n\n{#ThreadMicros - TableUtil.CountKeys(MicroTaskList)} free`
			})
		end)
	end,
})

CreateTaskbarButton("Code", {
	WindowConfig = {
		Name = "Interpreter",
		Text = "Input code string to run.\nIf it is not a link, it will be registered as a task.",
	},
	
	Callback = function(window)
		local connection
		
		connection = Keyboard:Connect("TextInputted", function(text, playerName)
			if window.Destroyed then
				connection:Unbind()
				connection = nil
				return
			end
			
			local name = ""
			
			for i = 1, 5 do
				name..= math.random(i, 5)
			end
			
			local success = CreateProcess(name, text)
			
			if success then
				window._Elements.contentFrame.Text = "Code Executing..."
			else
				window._Elements.contentFrame.Text = "No cores available. Please stop some tasks."
			end
		end)
	end,
})

CreateTaskbarButton("Radar", {
	Type = "Grid",
	Image = "http://www.roblox.com/asset/?id=10790307891",
	WindowConfig = {
		Name = "Radar",
		Type = "Custom",
		Color = Color3.fromHex("#2D2D2D"),
	},

	Callback = function(window)
		local Radar = require("Radar")

		print(Radar(window))
	end,
})

CreateTaskbarButton("Music", {
	Type = "Grid",
	Text = "Music",
	WindowConfig = {
		Name = "Music Player",
		Type = "Scroll",
		OverwriteIfExists = true,
	},
	Callback = function(window)
		local MusicIds = require("MusicPlayerIds")
		window.Layout = ListLayout(window, {
			Padding = UDim.new(0.05, 0)
		})

		for name, id in pairs(MusicIds) do
			local label = Screen:CreateElement("TextButton", {
				Size = UDim2.fromScale(1, 0.15),
				TextScaled = true,
				BackgroundColor3 = Color3.fromRGB(50, 50, 50),
				TextColor3 = Color3.fromRGB(255, 255 ,255),
				Text = StringUtil.SplitTitleCaps(name)
			})

			window:AddChild(label)
			local playing = false

			label.MouseButton1Click:Connect(function()
				if playing then
					SpeakerHandler.PlaySound(0, 0)
					playing = false
					return
				end

				playing = true
				SpeakerHandler.PlaySound(id, 1)
			end)
		end
		
		print(`Screen has {#Screen:GetElementMany()} elements`)
	end,
})


LoadPinnedFiles()
--SpeakerHandler.LoopSound(1846897737, 111)

local OSLibrary = {
	Screen = Screen,
	Keyboard = Keyboard,
	WindowHandler = WindowHandler,
	FileHandler = FileHandler,
	SpeakerHandler = SpeakerHandler,

	TaskManager = {
		CreateProcess = CreateProcess,
		StopProcess = StopProcess,
		TaskList = MicroTaskList
	},
	
	Elements = {
		GridLayout = GridLayout,
		ListLayout = ListLayout,
		InputButton = InputButton
	},
	
	Input = GetKeyboardInput,
	WindowInput = WindowInput
}


Disk:Write("OSLibrary", setmetatable({}, { __index = OSLibrary })) -- Stupid thing to stop "table cannot be cyclic"

while true do
	local dt = task.wait()
	local cursors = Screen:GetCursors()

	for playerName, data in pairs(PlayerCursors) do

		if not cursors[playerName] then
			data.label:Destroy()
			PlayerCursors[playerName] = nil
		end
	end

	for playerName, cursor in pairs(cursors) do
		local data = PlayerCursors[playerName]

		if not data then
			local component = Components.PlayerCursor(background)
			local label = component.playerCursor
			label.ImageColor3 = OSConfig.Accent

			data = {
				label = label
			}

			PlayerCursors[playerName] = data
		end

		data.label.Position = UDim2.fromOffset(cursor.X, cursor.Y)
		data.label.BackgroundColor3 = OSConfig.Accent
	end
	
	for taskName, resultInfo in pairs(ProcessResults) do -- Update task loop.
		ProcessResults[taskName] = nil
		ProcessResult(taskName, resultInfo)
	end
	
	SpeakerHandler:UpdateSoundLoop(dt)
end
