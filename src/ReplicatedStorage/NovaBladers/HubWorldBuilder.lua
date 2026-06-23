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
	part.Name = props.name or "HubPart"
	part.Parent = props.parent
	return part
end

local function buildFloor(parent)
	local cfg = HubConfig
	local floor = makePart({
		name = "Floor",
		size = cfg.FLOOR_SIZE,
		cframe = CFrame.new(cfg.FLOOR_CENTER + Vector3.new(0, -cfg.FLOOR_SIZE.Y / 2, 0)),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
		parent = parent,
	})
	floor.TopSurface = Enum.SurfaceType.Smooth
	return floor
end

local function buildWalls(parent)
	local cfg = HubConfig
	local halfX = cfg.FLOOR_SIZE.X / 2
	local halfZ = cfg.FLOOR_SIZE.Z / 2
	local h = cfg.WALL_HEIGHT
	local t = cfg.WALL_THICKNESS
	local wallColor = Color3.fromRGB(55, 60, 72)

	local walls = {
		{ size = Vector3.new(cfg.FLOOR_SIZE.X + t * 2, h, t), pos = Vector3.new(0, h / 2, halfZ + t / 2) },
		{ size = Vector3.new(cfg.FLOOR_SIZE.X + t * 2, h, t), pos = Vector3.new(0, h / 2, -halfZ - t / 2) },
		{ size = Vector3.new(t, h, cfg.FLOOR_SIZE.Z), pos = Vector3.new(halfX + t / 2, h / 2, 0) },
		{ size = Vector3.new(t, h, cfg.FLOOR_SIZE.Z), pos = Vector3.new(-halfX - t / 2, h / 2, 0) },
	}

	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	folder.Parent = parent

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = wallColor,
			material = Enum.Material.Concrete,
			parent = folder,
		})
	end
end

local function buildZoneMarker(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local pad = makePart({
		name = "Pad",
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		cframe = CFrame.new(zone.center - Vector3.new(0, zone.size.Y / 2 - 0.2, 0)),
		color = zone.color,
		material = Enum.Material.Neon,
		parent = folder,
	})
	pad.Transparency = 0.35

	local trigger = makePart({
		name = "Trigger",
		size = zone.size,
		cframe = CFrame.new(zone.center),
		color = zone.color,
		parent = folder,
	})
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanTouch = true

	local sign = makePart({
		name = "Sign",
		size = Vector3.new(zone.size.X * 0.6, 3, 0.3),
		cframe = CFrame.new(zone.center + Vector3.new(0, zone.size.Y / 2 + 2, 0)),
		color = zone.color,
		material = Enum.Material.Neon,
		parent = folder,
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

	return trigger
end

local function buildLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		size = cfg.size,
		cframe = CFrame.new(cfg.position),
		color = Color3.fromRGB(25, 28, 36),
		material = Enum.Material.SmoothPlastic,
		parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = cfg.face
	gui.CanvasSize = Vector2.new(600, 400)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.new(0, 10, 0, 55)
	list.Size = UDim2.new(1, -20, 1, -65)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = gui

	local lines = {}
	if entries and #entries > 0 then
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	buildFloor(hub)
	buildWalls(hub)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZoneMarker(zonesFolder, zone)
	end

	buildLeaderboardBoard(hub, leaderboardEntries)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

function HubWorldBuilder.updateLeaderboard(entries)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local list = gui:FindFirstChild("Entries", true)
	if not list then return end

	local lines = {}
	if entries and #entries > 0 then
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

return HubWorldBuilder
