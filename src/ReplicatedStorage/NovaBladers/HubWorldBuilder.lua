local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	for key, value in props do
		part[key] = value
	end
	return part
end

local function makeSign(text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(8, 3, 0.4),
		Position = position + Vector3.new(0, 5, 0),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
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

function HubWorldBuilder.build(config)
	local existing = workspace:FindFirstChild(config.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = config.HUB_NAME
	hub.Parent = workspace

	local floorY = config.SPAWN_POSITION.Y - 3.5
	local floorCenter = Vector3.new(config.SPAWN_POSITION.X, floorY, config.SPAWN_POSITION.Z)

	makePart({
		Name = "Floor",
		Size = config.FLOOR_SIZE,
		Position = floorCenter,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(22, 26, 38),
		Parent = hub,
	})

	local halfX = config.FLOOR_SIZE.X / 2
	local halfZ = config.FLOOR_SIZE.Z / 2
	local wallY = floorY + config.WALL_HEIGHT / 2
	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, config.WALL_THICKNESS), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, config.WALL_THICKNESS), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(config.WALL_THICKNESS, config.WALL_HEIGHT, config.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(config.WALL_THICKNESS, config.WALL_HEIGHT, config.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in wallDefs do
		makePart({
			Name = wall.name,
			Size = wall.size,
			Position = floorCenter + wall.pos,
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 44, 58),
			Parent = hub,
		})
	end

	makePart({
		Name = "SpawnPad",
		Size = Vector3.new(12, 0.4, 12),
		Position = Vector3.new(config.SPAWN_POSITION.X, floorY + 0.7, config.SPAWN_POSITION.Z),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(100, 180, 255),
		CanCollide = false,
		Parent = hub,
	})

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in config.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = zonesFolder

		makePart({
			Name = "Platform",
			Size = Vector3.new(zone.radius * 1.6, 0.5, zone.radius * 1.6),
			Position = Vector3.new(zone.position.X, floorY + 0.75, zone.position.Z),
			Material = Enum.Material.Neon,
			Color = zone.color,
			Transparency = 0.35,
			CanCollide = false,
			Parent = zoneFolder,
		})

		makeSign(zone.name, zone.position, zone.color).Parent = zoneFolder

		local marker = Instance.new("Part")
		marker.Name = "ZoneMarker"
		marker.Size = Vector3.new(1, 1, 1)
		marker.Position = zone.position
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = zoneFolder
	end

	return hub
end

return HubWorldBuilder
