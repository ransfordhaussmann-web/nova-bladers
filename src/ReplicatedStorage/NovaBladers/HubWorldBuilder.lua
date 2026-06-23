local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function createLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function createLeaderboardBoard(parent, config)
	local board = createPart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 7, 0.4),
		CFrame = CFrame.new(parent.Position + Vector3.new(0, 3.5, -4.5)),
		Color = Color3.fromRGB(30, 32, 42),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent.Parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStuds
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "BoardFrame"
	frame.Size = UDim2.fromOffset(config.LEADERBOARD_BOARD_SIZE.X, config.LEADERBOARD_BOARD_SIZE.Y)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(16, 56)
	list.Size = UDim2.new(1, -32, 1, -72)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextWrapped = true
	list.Text = "Lade Rangliste..."
	list.Parent = frame

	return board
end

function HubWorldBuilder.build(config)
	local existing = workspace:FindFirstChild(config.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = config.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = createPart({
		Name = "Floor",
		Size = config.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = config.FLOOR_SIZE.X / 2
	local halfZ = config.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = config.WALL_HEIGHT / 2

	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, wallThickness), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, wallThickness), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallThickness, config.WALL_HEIGHT, config.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, config.WALL_HEIGHT, config.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, def in wallDefs do
		createPart({
			Name = def.name,
			Size = def.size,
			Position = def.pos,
			Color = Color3.fromRGB(58, 62, 74),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = config.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in config.ZONES do
		local zonePart = createPart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		createLabel(zonePart, zone.name, zone.size.Y / 2 + 2)

		if zone.id == "hall_of_fame" then
			createLeaderboardBoard(zonePart, config)
		end
	end

	local centerSign = createPart({
		Name = "WelcomeSign",
		Size = Vector3.new(14, 1, 0.5),
		Position = Vector3.new(0, 6, -8),
		Color = Color3.fromRGB(70, 74, 90),
		Material = Enum.Material.Metal,
		Parent = hub,
	})
	createLabel(centerSign, "Nova Bladers Hub", 2)

	return hub
end

function HubWorldBuilder.updateLeaderboard(hub, entries)
	local leaderboardBoard = hub:FindFirstChild("LeaderboardBoard", true)
	if not leaderboardBoard then return end

	local surface = leaderboardBoard:FindFirstChild("LeaderboardSurface")
	if not surface then return end
	local frame = surface:FindFirstChild("BoardFrame")
	if not frame then return end
	local list = frame:FindFirstChild("Entries")
	if not list then return end

	local lines = {}
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
		end
	end
	list.Text = table.concat(lines, "\n")
end

return HubWorldBuilder
