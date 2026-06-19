local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function makeSign(text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 3, 0.4),
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local wallDefs = {
		{ Vector3.new(0, wallY, halfZ + wallThickness / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, -halfZ - wallThickness / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(halfX + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4) },
		{ Vector3.new(-halfX - wallThickness / 2, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4) },
	}

	for index, def in wallDefs do
		local wall = makePart({
			Name = "Wall" .. index,
			Position = def[1],
			Size = def[2],
			Color = Color3.fromRGB(55, 60, 75),
			Material = Enum.Material.Concrete,
		})
		wall.Parent = walls
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(90, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = zones

		local platform = makePart({
			Name = "Platform",
			Size = zone.size,
			Position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		})
		platform.Parent = zoneFolder

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.prompt
		prompt.ObjectText = zone.label
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.Parent = platform

		local signPos = zone.position + Vector3.new(0, 8, -zone.size.Z / 2 - 2)
		makeSign(zone.label .. "\n" .. zone.hint, signPos, zone.color).Parent = zoneFolder
	end

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if hub and hub:FindFirstChild("HubSpawn") then
		return hub.HubSpawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

return HubWorldBuilder
