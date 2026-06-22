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

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 3, 0.4),
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
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

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if board then
		board:Destroy()
	end

	board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 0.5),
		Position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 5, -7),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local lines = { "🏆 Ruhmeshalle" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = table.concat(lines, "\n")
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextScaled = false
		label.TextSize = 28
		label.Font = Enum.Font.GothamMedium
		label.Parent = gui
	end

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorY = 0
	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = floorY + HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallThickness, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallThickness, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wallData in walls do
		makePart({
			Name = "Wall" .. index,
			Position = wallData[1],
			Size = wallData[2],
			Color = Color3.fromRGB(60, 65, 78),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = zonesFolder

		local platform = makePart({
			Name = "Platform",
			Size = Vector3.new(zone.size.X, 0.5, zone.size.Z),
			Position = zone.position + Vector3.new(0, 0.25, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = zoneFolder,
		})

		local trigger = makePart({
			Name = "Trigger",
			Size = zone.size,
			Position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
			Transparency = 1,
			CanCollide = false,
			Parent = zoneFolder,
		})

		local arch = makePart({
			Name = "Arch",
			Size = Vector3.new(zone.size.X * 0.9, 0.6, 0.6),
			Position = zone.position + Vector3.new(0, zone.size.Y - 1, zone.size.Z / 2 + 0.5),
			Color = zone.color,
			Material = Enum.Material.Metal,
			Parent = zoneFolder,
		})

		addSign(zoneFolder, zone.name, arch.Position + Vector3.new(0, 2.2, 0), zone.color)

		local attr = Instance.new("StringValue")
		attr.Name = "ZoneId"
		attr.Value = zone.id
		attr.Parent = trigger
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
