local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function createZoneMarker(parent, zone)
	local pillar = createPart({
		parent = parent,
		name = zone.id,
		size = Vector3.new(8, 0.4, 8),
		cframe = CFrame.new(zone.position + Vector3.new(0, 0.2, 0)),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.35,
	})

	local sign = createPart({
		parent = parent,
		name = zone.id .. "Sign",
		size = Vector3.new(6, 4, 0.4),
		cframe = CFrame.new(zone.position + Vector3.new(0, 3, 0)),
		color = Color3.fromRGB(25, 25, 30),
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.label
	label.TextColor3 = zone.color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local attr = Instance.new("Configuration")
	attr.Name = "ZoneMeta"
	attr:SetAttribute("ZoneId", zone.id)
	attr:SetAttribute("Action", zone.action)
	attr:SetAttribute("Position", zone.position)
	attr.Parent = pillar

	return pillar
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = createPart({
		parent = parent,
		name = "LeaderboardBoard",
		size = cfg.size,
		cframe = CFrame.new(cfg.position),
		color = Color3.fromRGB(20, 22, 28),
	})

	local gui = board:FindFirstChild("LeaderboardGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "LeaderboardGui"
		gui.Face = cfg.face
		gui.CanvasSize = Vector2.new(700, 400)
		gui.Parent = board
	end

	local title = gui:FindFirstChild("Title")
	if not title then
		title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 48)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 220, 100)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = gui
	end

	local list = gui:FindFirstChild("List")
	if not list then
		list = Instance.new("TextLabel")
		list.Name = "List"
		list.Size = UDim2.new(1, -16, 1, -56)
		list.Position = UDim2.new(0, 8, 0, 52)
		list.BackgroundTransparency = 1
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = Color3.fromRGB(230, 230, 240)
		list.TextSize = 22
		list.Font = Enum.Font.GothamMedium
		list.TextWrapped = true
		list.Parent = gui
	end

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

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local floor = createPart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, 0, 0),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, wallY, halfZ) },
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, wallY, -halfZ) },
		{ size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
		{ size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
	}

	for i, def in wallDefs do
		createPart({
			parent = walls,
			name = "Wall" .. i,
			size = def.size,
			cframe = CFrame.new(def.pos),
			color = Color3.fromRGB(28, 30, 38),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZoneMarker(zones, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
