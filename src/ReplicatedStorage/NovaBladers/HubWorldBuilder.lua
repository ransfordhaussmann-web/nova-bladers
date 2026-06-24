local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeWall(parent, center, size, color)
	makePart({
		parent = parent,
		name = "Wall",
		size = size,
		cframe = CFrame.new(center),
		color = color or Color3.fromRGB(55, 58, 72),
		material = Enum.Material.Concrete,
	})
end

local function makeZoneMarker(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local pad = makePart({
		parent = folder,
		name = "Pad",
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		cframe = CFrame.new(zone.position.X, 0.2, zone.position.Z),
		color = zone.color,
		material = Enum.Material.Neon,
	})
	pad.Transparency = 0.35

	local sign = makePart({
		parent = folder,
		name = "Sign",
		size = Vector3.new(zone.size.X * 0.8, 4, 0.4),
		cframe = CFrame.new(zone.position.X, 3, zone.position.Z - zone.size.Z * 0.5 - 1),
		color = zone.color,
		material = Enum.Material.SmoothPlastic,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = zone.size
	trigger.CFrame = CFrame.new(zone.position)
	trigger.Parent = folder

	return folder
end

local function makeLeaderboardBoard(parent, zone, entries, boardSize)
	local board = makePart({
		parent = parent,
		name = "LeaderboardBoard",
		size = Vector3.new(8, 6, 0.4),
		cframe = CFrame.new(zone.position + Vector3.new(0, 4, zone.size.Z * 0.5 + 2)),
		color = Color3.fromRGB(30, 32, 42),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(boardSize.X, boardSize.Y)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 215, 80)
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 52)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build(config, leaderboardEntries)
	local existing = workspace:FindFirstChild(config.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = config.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = 0
	local halfX = config.FLOOR_SIZE.X * 0.5
	local halfZ = config.FLOOR_SIZE.Z * 0.5

	makePart({
		parent = hub,
		name = "Floor",
		size = config.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY - config.FLOOR_SIZE.Y * 0.5, 0),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
	})

	local wallH = config.WALL_HEIGHT
	local t = config.WALL_THICKNESS
	makeWall(hub, Vector3.new(0, wallH * 0.5, halfZ + t * 0.5), Vector3.new(config.FLOOR_SIZE.X + t * 2, wallH, t))
	makeWall(hub, Vector3.new(0, wallH * 0.5, -halfZ - t * 0.5), Vector3.new(config.FLOOR_SIZE.X + t * 2, wallH, t))
	makeWall(hub, Vector3.new(halfX + t * 0.5, wallH * 0.5, 0), Vector3.new(t, wallH, config.FLOOR_SIZE.Z))
	makeWall(hub, Vector3.new(-halfX - t * 0.5, wallH * 0.5, 0), Vector3.new(t, wallH, config.FLOOR_SIZE.Z))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in config.ZONES do
		makeZoneMarker(zonesFolder, zone)
	end

	local hallZone = config.ZONES.HallOfFame
	if hallZone then
		makeLeaderboardBoard(hub, hallZone, leaderboardEntries or {}, config.LEADERBOARD_BOARD_SIZE)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = config.SPAWN_CFRAME
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
