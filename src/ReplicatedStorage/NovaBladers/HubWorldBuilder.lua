local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or HubConfig.THEME.Floor
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeZoneMarker(zone, parent, theme)
	local color = theme[zone.colorKey] or theme.Accent
	local frame = makePart({
		name = "Zone_" .. zone.id,
		parent = parent,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = color,
		transparency = 0.55,
		canCollide = false,
		material = Enum.Material.Neon,
	})
	frame:SetAttribute("ZoneId", zone.id)
	frame:SetAttribute("ZoneLabel", zone.label)
	frame:SetAttribute("ZoneHint", zone.hint)
	frame:SetAttribute("ZoneAction", zone.action)

	local sign = makePart({
		name = "Sign",
		parent = frame,
		size = Vector3.new(zone.size.X * 0.9, 2.5, 0.4),
		cframe = frame.CFrame * CFrame.new(0, zone.size.Y * 0.35, -zone.size.Z * 0.35),
		color = theme.Wall,
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = zone.label
	label.Parent = gui

	local ring = makePart({
		name = "Ring",
		parent = frame,
		size = Vector3.new(zone.size.X + 2, 0.3, zone.size.Z + 2),
		cframe = CFrame.new(zone.position.X, zone.position.Y - zone.size.Y * 0.45, zone.position.Z),
		color = color,
		transparency = 0.25,
		material = Enum.Material.Neon,
		canCollide = false,
	})

	return frame
end

local function buildWalls(parent, theme)
	local floor = HubConfig.FLOOR_SIZE
	local center = HubConfig.FLOOR_CENTER
	local h = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS
	local halfX = floor.X * 0.5
	local halfZ = floor.Z * 0.5
	local wallY = center.Y + h * 0.5

	local walls = {
		{ size = Vector3.new(floor.X + t * 2, h, t), pos = Vector3.new(center.X, wallY, center.Z + halfZ + t * 0.5) },
		{ size = Vector3.new(floor.X + t * 2, h, t), pos = Vector3.new(center.X, wallY, center.Z - halfZ - t * 0.5) },
		{ size = Vector3.new(t, h, floor.Z), pos = Vector3.new(center.X + halfX + t * 0.5, wallY, center.Z) },
		{ size = Vector3.new(t, h, floor.Z), pos = Vector3.new(center.X - halfX - t * 0.5, wallY, center.Z) },
	}

	for i, spec in walls do
		makePart({
			name = "Wall" .. i,
			parent = parent,
			size = spec.size,
			cframe = CFrame.new(spec.pos),
			color = theme.Wall,
			material = Enum.Material.Concrete,
		})
	end
end

local function buildLeaderboardBoard(parent, theme)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = cfg.size,
		cframe = CFrame.new(cfg.position),
		color = theme.Wall,
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardSurface"
	gui.Face = cfg.face
	gui.CanvasSize = Vector2.new(600, 400)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = theme.Hall
	title.TextSize = 28
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 12, 0, 52)
	list.Size = UDim2.new(1, -24, 1, -60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local theme = HubConfig.THEME
	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	makePart({
		name = "Floor",
		parent = geometry,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(HubConfig.FLOOR_CENTER),
		color = theme.Floor,
		material = Enum.Material.Grass,
	})

	buildWalls(geometry, theme)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		makeZoneMarker(zone, zonesFolder, theme)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	buildLeaderboardBoard(hub, theme)

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 40
	lighting.Color = theme.Accent
	lighting.Parent = makePart({
		name = "HubLight",
		parent = geometry,
		size = Vector3.new(2, 1, 2),
		cframe = CFrame.new(0, 14, 0),
		color = theme.Accent,
		transparency = 1,
		canCollide = false,
	})

	return hub
end

function HubWorldBuilder.getZoneParts(hub)
	local zones = {}
	local folder = hub:FindFirstChild("Zones")
	if not folder then return zones end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("ZoneId") then
			table.insert(zones, child)
		end
	end
	return zones
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChild("LeaderboardSurface")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
