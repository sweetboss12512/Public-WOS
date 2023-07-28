local TurretInfo = {
	Name = nil, -- Name of the turret
	Type = nil, -- Turret type
	Min = nil, -- turret min
	Max = nil, -- turret max
	
	Gyro = GetPartFromPort(1, "Gyro"),
	PowerSwitch = GetPartFromPort(1, "Switch")
}

local function GetWirelessObject(port, objectName)
	if typeof(port) == "number" then
		port = GetPort(port)
	end

	local attempts = 0
	local connection
	local object

	connection = port:Connect("Triggered", function(wirelessPort)
		print("Happened")
		print(port)
		print(wirelessPort)
		object = GetPartFromPort(wirelessPort, objectName)
		connection:Unbind()
	end)

	repeat
		attempts += 1
		task.wait()
	until object or attempts >= 250

	if attempts >= 250 then
		print("Failed to get object '"..objectName.."'")
		connection:Unbind()
	end

	print("Attempts: "..attempts)
	return object
end

local Disk = GetWirelessObject(2, "Disk")

if Disk then
	local RegisterFunction = Disk:Read("RegisterTurret")
	
	RegisterFunction(TurretInfo)
else
	print("Error getting disk")
end
