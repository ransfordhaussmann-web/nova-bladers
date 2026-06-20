local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

local function addZoneLabel(parent, zone, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.55 + 2, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 80
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = zone.label
	title.Parent = billboard

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(210, 210, 220)
	hint.TextWrapped = true
	hint.Text = text or zone.hint
	hint.Parent = billboard
end

local function addProximityPrompt(parent, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zone.action)
	prompt:SetAttribute("ZoneId", zone.id)
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build(origin)
	origin = origin or HubConfig.ORIGIN

	local hub = Instance.new("Model")
	hub.Name = "HubWorld"

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
		cframe = CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y / 2, 0)),
	})

	makePart({
		name = "FloorAccent",
		parent = hub,
		size = Vector3.new(HubConfig.FLOOR_SIZE.X - 8, 0.4, HubConfig.FLOOR_SIZE.Z - 8),
		color = Color3.fromRGB(55, 60, 74),
		material = Enum.Material.Neon,
		canCollide = false,
		cframe = floor.CFrame * CFrame.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 0.2, 0),
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.EDGE_WALL_HEIGHT / 2 + 1

	for _, spec in {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.EDGE_WALL_HEIGHT, 2), offset = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.EDGE_WALL_HEIGHT, 2), offset = Vector3.new(0, wallY, halfZ) },
		{ name = "WallEast", size = Vector3.new(2, HubConfig.EDGE_WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), offset = Vector3.new(halfX, wallY, 0) },
		{ name = "WallWest", size = Vector3.new(2, HubConfig.EDGE_WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), offset = Vector3.new(-halfX, wallY, 0) },
	} do
		makePart({
			name = spec.name,
			parent = hub,
			size = spec.size,
			color = Color3.fromRGB(28, 30, 38),
			material = Enum.Material.Concrete,
			cframe = CFrame.new(origin + spec.offset),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(100, 180, 255)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	local centerPillar = makePart({
		name = "CenterPillar",
		parent = hub,
		size = Vector3.new(4, 12, 4),
		color = Color3.fromRGB(70, 75, 95),
		material = Enum.Material.Metal,
		cframe = CFrame.new(origin + Vector3.new(0, 6, 0)),
	})

	local sign = Instance.new("BillboardGui")
	sign.Name = "HubTitle"
	sign.Size = UDim2.fromOffset(280, 48)
	sign.StudsOffset = Vector3.new(0, 8, 0)
	sign.AlwaysOnTop = false
	sign.MaxDistance = 120
	sign.Parent = centerPillar

	local signText = Instance.new("TextLabel")
	signText.BackgroundTransparency = 1
	signText.Size = UDim2.fromScale(1, 1)
	signText.Font = Enum.Font.GothamBlack
	signText.TextSize = 26
	signText.TextColor3 = Color3.fromRGB(140, 200, 255)
	signText.Text = "Nova Bladers Hub"
	signText.Parent = sign

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = hub,
			size = zone.size,
			color = zone.color,
			material = Enum.Material.Neon,
			cframe = CFrame.new(origin + zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
		})
		zonePart.Transparency = 0.35
		zonePart:SetAttribute("HubZoneId", zone.id)
		zonePart:SetAttribute("HubAction", zone.action)
		addZoneLabel(zonePart, zone)
		addProximityPrompt(zonePart, zone)
	end

	hub.PrimaryPart = floor
	hub.Parent = workspace
	return hub
end

function HubWorldBuilder.getSpawnCFrame(origin)
	origin = origin or HubConfig.ORIGIN
	return CFrame.new(origin + HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

return HubWorldBuilder
