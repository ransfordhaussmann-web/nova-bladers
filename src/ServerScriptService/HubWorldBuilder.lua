local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function createLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, offsetY or 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

local function createZone(folder, zoneId, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneId
	zoneFolder.Parent = folder

	local platform = createPart({
		Name = "Platform",
		Parent = zoneFolder,
		Size = zoneConfig.size,
		CFrame = CFrame.new(zoneConfig.position),
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zoneConfig.promptText
	prompt.ObjectText = zoneConfig.label
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zoneConfig.promptAction)
	prompt.Parent = platform

	createLabel(platform, zoneConfig.label, zoneConfig.size.Y * 0.5 + 2)
	return zoneFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = createPart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.HUB_FLOOR_SIZE,
		CFrame = CFrame.new(0, HubConfig.HUB_FLOOR_Y, 0),
		Color = Color3.fromRGB(45, 50, 62),
		Material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.HUB_SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.35
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Parent = hub

	-- Walk paths from spawn to each zone
	local pathColor = Color3.fromRGB(70, 75, 90)
	createPart({
		Name = "PathCenter",
		Parent = hub,
		Size = Vector3.new(6, 0.4, 80),
		CFrame = CFrame.new(0, HubConfig.HUB_FLOOR_Y + 0.7, -2),
		Color = pathColor,
		Material = Enum.Material.Concrete,
	})
	createPart({
		Name = "PathWest",
		Parent = hub,
		Size = Vector3.new(40, 0.4, 6),
		CFrame = CFrame.new(-20, HubConfig.HUB_FLOOR_Y + 0.7, 0),
		Color = pathColor,
		Material = Enum.Material.Concrete,
	})
	createPart({
		Name = "PathEast",
		Parent = hub,
		Size = Vector3.new(40, 0.4, 6),
		CFrame = CFrame.new(20, HubConfig.HUB_FLOOR_Y + 0.7, 0),
		Color = pathColor,
		Material = Enum.Material.Concrete,
	})

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zoneConfig in HubConfig.ZONES do
		createZone(zonesFolder, zoneId, zoneConfig)
	end

	-- Low boundary walls so players stay on the map
	local half = HubConfig.HUB_FLOOR_SIZE.X * 0.5
	local wallH = 4
	local wallY = HubConfig.HUB_FLOOR_Y + wallH * 0.5
	local wallThickness = 2
	local wallColor = Color3.fromRGB(35, 38, 48)

	for _, spec in {
		{ pos = Vector3.new(0, wallY, half), size = Vector3.new(HubConfig.HUB_FLOOR_SIZE.X, wallH, wallThickness) },
		{ pos = Vector3.new(0, wallY, -half), size = Vector3.new(HubConfig.HUB_FLOOR_SIZE.X, wallH, wallThickness) },
		{ pos = Vector3.new(half, wallY, 0), size = Vector3.new(wallThickness, wallH, HubConfig.HUB_FLOOR_SIZE.Z) },
		{ pos = Vector3.new(-half, wallY, 0), size = Vector3.new(wallThickness, wallH, HubConfig.HUB_FLOOR_SIZE.Z) },
	} do
		createPart({
			Name = "Boundary",
			Parent = hub,
			Size = spec.size,
			CFrame = CFrame.new(spec.pos),
			Color = wallColor,
			Material = Enum.Material.Metal,
		})
	end

	return hub
end

return HubWorldBuilder
