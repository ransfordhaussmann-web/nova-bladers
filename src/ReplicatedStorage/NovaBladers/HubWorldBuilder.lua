local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function addLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return billboard
end

local function buildZone(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local pad = makePart({
		Name = "Pad",
		Parent = folder,
		Size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		CFrame = CFrame.new(zone.center + Vector3.new(0, -0.2, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
	})

	local marker = makePart({
		Name = "Marker",
		Parent = folder,
		Size = Vector3.new(4, 10, 1),
		CFrame = CFrame.new(zone.center + Vector3.new(0, 5, -zone.size.Z * 0.5 + 1)),
		Color = zone.color,
		Material = Enum.Material.Metal,
	})

	addLabel(marker, zone.label, 4)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(zone.size.X, zone.size.Z) * 0.45
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	return folder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})

	local wallThickness = 2
	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(55, 58, 70),
			Material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZone(zonesFolder, zone)
	end

	local centerPillar = makePart({
		Name = "CenterPillar",
		Parent = hub,
		Size = Vector3.new(8, 14, 8),
		CFrame = CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(70, 75, 95),
		Material = Enum.Material.Metal,
	})
	addLabel(centerPillar, "Nova Bladers Hub", 8)

	hub.PrimaryPart = floor
	return hub
end

return HubWorldBuilder
