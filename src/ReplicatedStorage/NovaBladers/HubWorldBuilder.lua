local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	if props.parent then
		part.Parent = props.parent
	end
	return part
end

local function buildZoneMarker(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	makePart({
		name = "Platform",
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		cframe = CFrame.new(zone.position.X, HubConfig.FLOOR_Y + 0.2, zone.position.Z),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.35,
		parent = folder,
	})

	local trigger = makePart({
		name = "Trigger",
		size = zone.size,
		cframe = CFrame.new(zone.position),
		transparency = 1,
		canCollide = false,
		parent = folder,
	})
	trigger:SetAttribute("ZoneId", zone.id)

	local sign = makePart({
		name = "Sign",
		size = Vector3.new(6, 3, 0.4),
		cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2, 0)),
		color = zone.color,
		material = Enum.Material.SmoothPlastic,
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

	return folder, trigger
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			name = "LeaderboardBoard",
			size = Vector3.new(10, 7, 0.4),
			cframe = CFrame.new(cfg.position),
			color = HubConfig.THEME.wall,
			material = Enum.Material.Slate,
			parent = parent,
		})
	end

	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Face = cfg.face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
	end

	local frame = gui:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromOffset(cfg.size.X, cfg.size.Y)
		frame.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
		frame.BorderSizePixel = 0
		frame.Parent = gui
	end

	local title = frame:FindFirstChild("Title")
	if not title then
		title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 40)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = HubConfig.THEME.light
		title.Font = Enum.Font.GothamBold
		title.TextSize = 22
		title.Parent = frame
	end

	local list = frame:FindFirstChild("List")
	if not list then
		list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.fromOffset(0, 44)
		list.Size = UDim2.new(1, 0, 1, -44)
		list.BackgroundTransparency = 1
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = Color3.fromRGB(220, 225, 240)
		list.Font = Enum.Font.Gotham
		list.TextSize = 18
		list.Parent = frame
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build(entries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		HubWorldBuilder.buildLeaderboardBoard(existing, entries or {})
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, HubConfig.FLOOR_Y - HubConfig.FLOOR_SIZE.Y * 0.5, 0),
		color = HubConfig.THEME.floor,
		material = Enum.Material.Concrete,
		parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH * 0.5, halfZ + t * 0.5), Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t) },
		{ Vector3.new(0, wallH * 0.5, -halfZ - t * 0.5), Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t) },
		{ Vector3.new(halfX + t * 0.5, wallH * 0.5, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX - t * 0.5, wallH * 0.5, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = HubConfig.THEME.wall,
			material = Enum.Material.Brick,
			parent = hub,
		})
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

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZoneMarker(zonesFolder, zone)
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = HubConfig.THEME.accent
	light.Parent = floor

	HubWorldBuilder.buildLeaderboardBoard(hub, entries or {})

	return hub
end

return HubWorldBuilder
