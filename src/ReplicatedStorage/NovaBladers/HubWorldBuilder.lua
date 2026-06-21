local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	part.Parent = parent
	return part
end

local function createSign(parent, text, position, color)
	local sign = createPart(parent, {
		Name = "Sign",
		Size = Vector3.new(8, 3, 0.4),
		Position = position + Vector3.new(0, 5, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	return sign
end

local function createZoneMarker(parent, zone)
	local marker = createPart(parent, {
		Name = zone.id,
		Size = Vector3.new(14, 0.6, 14),
		Position = zone.position + Vector3.new(0, 0.3, 0),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})

	local ring = createPart(parent, {
		Name = zone.id .. "Ring",
		Size = Vector3.new(16, 0.2, 16),
		Position = zone.position + Vector3.new(0, 0.05, 0),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(0, 0, 90)

	createSign(parent, zone.label, zone.position, zone.color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = marker

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = marker

	return marker
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if board then
		board:Destroy()
	end

	local hallZone = HubConfig.ZONES.HallOfFame
	board = createPart(parent, {
		Name = "LeaderboardBoard",
		Size = Vector3.new(
			HubConfig.LEADERBOARD_BOARD_SIZE.X,
			HubConfig.LEADERBOARD_BOARD_SIZE.Y,
			0.4
		),
		Position = hallZone.position + Vector3.new(0, 5, 8),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.SmoothPlastic,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.18, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Text = "🏆 Nova Liga — Top 5"
	title.Parent = gui

	local body = Instance.new("TextLabel")
	body.Name = "Entries"
	body.Position = UDim2.new(0, 0, 0.2, 0)
	body.Size = UDim2.new(1, 0, 0.78, 0)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextScaled = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top

	local lines = {}
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	end
	body.Text = table.concat(lines, "\n")
	body.Parent = gui

	return board
end

function HubWorldBuilder.build(leaderboardEntries)
	local workspaceHub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if workspaceHub then
		workspaceHub:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = createPart(hub, {
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = true
	spawn.Color = Color3.fromRGB(90, 120, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallHeight = HubConfig.WALL_HEIGHT

	local walls = {
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallHeight, 2), Position = Vector3.new(0, wallHeight / 2, -halfZ) },
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallHeight, 2), Position = Vector3.new(0, wallHeight / 2, halfZ) },
		{ Size = Vector3.new(2, wallHeight, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallHeight / 2, 0) },
		{ Size = Vector3.new(2, wallHeight, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallHeight / 2, 0) },
	}

	for index, wall in walls do
		createPart(hub, {
			Name = "Wall" .. index,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
		})
	end

	createPart(hub, {
		Name = "CenterPath",
		Size = Vector3.new(4, 0.2, HubConfig.FLOOR_SIZE.Z - 10),
		Position = Vector3.new(0, 0.6, 0),
		Color = Color3.fromRGB(70, 90, 140),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})

	for _, zone in HubConfig.ZONES do
		createZoneMarker(hub, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, leaderboardEntries or {})

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 0.6
	lighting.Range = 80
	lighting.Parent = floor

	return hub
end

return HubWorldBuilder
