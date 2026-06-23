local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(part, title, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = title
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function addNeonRing(parent, position, size, color)
	local ring = makePart({
		Name = "NeonRing",
		Parent = parent,
		Position = position + Vector3.new(0, 0.15, 0),
		Size = Vector3.new(size.X + 1.5, 0.2, size.Z + 1.5),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	ring.Transparency = 0.15
end

function HubWorldBuilder.buildLeaderboardBoard(parent, zonePart)
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Position = zonePart.Position + Vector3.new(0, 6, -zonePart.Size.Z * 0.35),
		Size = Vector3.new(10, 7, 0.4),
		Color = Color3.fromRGB(30, 32, 42),
		Material = Enum.Material.Slate,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(500, 350)
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, -16, 1, -60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 18
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.Text = "Lade Bestenliste…"
	list.Parent = frame

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		Name = "HubFloor",
		Parent = hub,
		Position = Vector3.new(0, floorSize.Y * 0.5, 0),
		Size = floorSize,
		Color = Color3.fromRGB(38, 42, 52),
		Material = Enum.Material.Concrete,
	})

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5 + floorSize.Y
	local wallThickness = 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallThickness * 0.5), Vector3.new(floorSize.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, -halfZ - wallThickness * 0.5), Vector3.new(floorSize.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(halfX + wallThickness * 0.5, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z + 4) },
		{ Vector3.new(-halfX - wallThickness * 0.5, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z + 4) },
	}

	for index, wall in walls do
		makePart({
			Name = "HubWall" .. index,
			Parent = hub,
			Position = wall[1],
			Size = wall[2],
			Color = Color3.fromRGB(55, 58, 70),
			Material = Enum.Material.Brick,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zoneParts = {}
	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zoneId,
			Parent = zonesFolder,
			Position = zone.position,
			Size = zone.size,
			Color = zone.color,
			Material = Enum.Material.SmoothPlastic,
		})
		zonePart.Transparency = 0.25
		addNeonRing(zonesFolder, zone.position, zone.size, zone.color)
		addZoneLabel(zonePart, zone.name, zone.color)
		zoneParts[zoneId] = zonePart
	end

	local leaderboardBoard = HubWorldBuilder.buildLeaderboardBoard(hub, zoneParts.HallOfFame)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Neutral = true
	spawn.Parent = hub

	return hub, zoneParts, leaderboardBoard
end

return HubWorldBuilder
