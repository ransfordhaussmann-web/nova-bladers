local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position)
	part.Color = props.color or Color3.fromRGB(40, 44, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = zone.label
	label.Parent = billboard
end

local function addProximityPrompt(part, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HubConfig.INTERACT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zone.id)
	prompt.Parent = part
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, 1, 0),
		color = Color3.fromRGB(28, 32, 44),
		material = Enum.Material.Slate,
	})

	makePart({
		name = "FloorAccent",
		parent = hub,
		size = Vector3.new(HubConfig.FLOOR_SIZE.X - 8, 0.4, HubConfig.FLOOR_SIZE.Z - 8),
		position = Vector3.new(0, 2.2, 0),
		color = Color3.fromRGB(55, 65, 95),
		material = Enum.Material.Neon,
		canCollide = false,
	})

	makePart({
		name = "SpawnPad",
		parent = hub,
		size = Vector3.new(12, 0.6, 12),
		position = HubConfig.SPAWN_POSITION - Vector3.new(0, 3.3, 0),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5 + 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(20, 22, 30),
			material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
		})
		zonePart.Transparency = 0.35
		zonePart:SetAttribute("ZoneId", zone.id)

		addZoneLabel(zonePart, zone)
		addProximityPrompt(zonePart, zone)

		local ring = makePart({
			name = zone.id .. "_Ring",
			parent = zonesFolder,
			size = Vector3.new(zone.size.X + 4, 0.3, zone.size.Z + 4),
			position = zone.position - Vector3.new(0, zone.size.Y * 0.5 - 0.2, 0),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		ring.Transparency = 0.5
	end

	local centerPillar = makePart({
		name = "CenterPillar",
		parent = hub,
		size = Vector3.new(4, 14, 4),
		position = Vector3.new(0, 9, 0),
		color = Color3.fromRGB(70, 80, 120),
		material = Enum.Material.Metal,
	})

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 24
	light.Color = Color3.fromRGB(140, 180, 255)
	light.Parent = centerPillar

	return hub
end

return HubWorldBuilder
