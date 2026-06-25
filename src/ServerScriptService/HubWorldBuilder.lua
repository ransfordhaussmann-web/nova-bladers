local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent
	return part
end

local function addNeonStrip(parent, cframe, size, color)
	local strip = makePart({
		Name = "NeonStrip",
		Parent = parent,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	return strip
end

local function addZoneMarker(parent, zoneId, position, color, height)
	local marker = makePart({
		Name = "Zone_" .. zoneId,
		Parent = parent,
		Size = Vector3.new(zoneId == "ArenaGate" and 16 or 12, 0.4, zoneId == "ArenaGate" and 16 or 12),
		CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	marker:SetAttribute("ZoneId", zoneId)

	local pillar = makePart({
		Name = "Pillar",
		Parent = marker,
		Size = Vector3.new(1.2, height, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2 + 0.5, 0)),
		Color = color,
		Material = Enum.Material.Metal,
	})

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = pillar

	return marker
end

local function buildArenaGate(parent, position, color)
	local folder = Instance.new("Folder")
	folder.Name = "ArenaGate"
	folder.Parent = parent

	local cfg = HubConfig.STRUCTURES
	local halfW = cfg.ArenaArchWidth / 2
	local archH = cfg.ArenaArchHeight

	local leftPillar = makePart({
		Name = "LeftPillar",
		Parent = folder,
		Size = Vector3.new(2.5, archH, 2.5),
		CFrame = CFrame.new(position + Vector3.new(-halfW, archH / 2, 0)),
		Color = color,
		Material = Enum.Material.Metal,
	})
	local rightPillar = leftPillar:Clone()
	rightPillar.Name = "RightPillar"
	rightPillar.CFrame = CFrame.new(position + Vector3.new(halfW, archH / 2, 0))
	rightPillar.Parent = folder

	local lintel = makePart({
		Name = "Lintel",
		Parent = folder,
		Size = Vector3.new(cfg.ArenaArchWidth + 2, 2, 3),
		CFrame = CFrame.new(position + Vector3.new(0, archH, 0)),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
	})

	addNeonStrip(folder, CFrame.new(position + Vector3.new(0, archH + 0.5, 0)), Vector3.new(cfg.ArenaArchWidth, 0.4, 0.6), color)

	local portal = makePart({
		Name = "Portal",
		Parent = folder,
		Size = Vector3.new(cfg.ArenaArchWidth - 4, archH - 2, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, archH / 2, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.7,
		CanCollide = false,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, archH + 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = lintel

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 22
	label.Text = "ARENA"
	label.Parent = billboard

	return folder
end

local function buildBeyTerminal(parent, position, color)
	local folder = Instance.new("Folder")
	folder.Name = "BeyTerminal"
	folder.Parent = parent

	local base = makePart({
		Name = "Base",
		Parent = folder,
		Size = Vector3.new(8, 1, 6),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Metal,
	})

	local screen = makePart({
		Name = "Screen",
		Parent = folder,
		Size = Vector3.new(6, 5, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 4, -2.8)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(180, 40)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = screen

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = "BEY-TERMINAL"
	label.Parent = billboard

	return folder
end

local function buildStatsPylon(parent, position, color)
	local folder = Instance.new("Folder")
	folder.Name = "StatsBoard"
	folder.Parent = parent

	local cfg = HubConfig.STRUCTURES
	local pillar = makePart({
		Name = "Pillar",
		Parent = folder,
		Size = Vector3.new(3, cfg.StatsPylonHeight, 3),
		CFrame = CFrame.new(position + Vector3.new(0, cfg.StatsPylonHeight / 2, 0)),
		Color = Color3.fromRGB(40, 45, 60),
		Material = Enum.Material.Metal,
	})

	local board = makePart({
		Name = "Board",
		Parent = folder,
		Size = Vector3.new(10, 7, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, cfg.StatsPylonHeight - 2, -1.8)),
		Color = Color3.fromRGB(20, 22, 32),
		Material = Enum.Material.SmoothPlastic,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "StatsSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = color
	title.TextSize = 24
	title.Text = "NOVA BLADERS"
	title.Parent = surface

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, -16, 1, -50)
	statsLabel.Position = UDim2.fromOffset(8, 45)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextSize = 18
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = "Stats laden..."
	statsLabel.TextWrapped = true
	statsLabel.Parent = surface

	local leaderboardLabel = Instance.new("TextLabel")
	leaderboardLabel.Name = "LeaderboardLabel"
	leaderboardLabel.Size = UDim2.new(1, -16, 0, 120)
	leaderboardLabel.Position = UDim2.fromOffset(8, 200)
	leaderboardLabel.BackgroundTransparency = 1
	leaderboardLabel.Font = Enum.Font.Gotham
	leaderboardLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	leaderboardLabel.TextSize = 16
	leaderboardLabel.TextXAlignment = Enum.TextXAlignment.Left
	leaderboardLabel.TextYAlignment = Enum.TextYAlignment.Top
	leaderboardLabel.Text = ""
	leaderboardLabel.TextWrapped = true
	leaderboardLabel.Parent = surface

	return folder, statsLabel, leaderboardLabel
end

local function buildPaths(parent, colors)
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = parent

	local spawn = HubConfig.SPAWN
	local zones = HubConfig.ZONES

	for _, zone in zones do
		local start = Vector3.new(spawn.X, HubConfig.FLOOR_Y + 0.15, spawn.Z)
		local finish = Vector3.new(zone.position.X, HubConfig.FLOOR_Y + 0.15, zone.position.Z)
		local delta = finish - start
		local length = delta.Magnitude
		if length > 1 then
			local mid = start + delta / 2
			makePart({
				Name = "Path_" .. zone.id,
				Parent = paths,
				Size = Vector3.new(6, 0.3, length),
				CFrame = CFrame.lookAt(mid, finish),
				Color = colors.Path,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end
end

function HubWorldBuilder.getStatsBoardLabels(root)
	local statsFolder = root:FindFirstChild("StatsBoard")
	if not statsFolder then return nil, nil end
	local board = statsFolder:FindFirstChild("Board")
	if not board then return nil, nil end
	local surface = board:FindFirstChild("StatsSurface")
	if not surface then return nil, nil end
	return surface:FindFirstChild("StatsLabel"), surface:FindFirstChild("LeaderboardLabel")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = HubConfig.ROOT_NAME
	root.Parent = workspace

	local colors = HubConfig.COLORS
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		Name = "Floor",
		Parent = root,
		Size = Vector3.new(floorSize.X, 1, floorSize.Y),
		CFrame = CFrame.new(0, HubConfig.FLOOR_Y - 0.5, 0),
		Color = colors.Floor,
		Material = Enum.Material.Slate,
	})

	makePart({
		Name = "FloorAccent",
		Parent = root,
		Size = Vector3.new(floorSize.X - 8, 0.2, floorSize.Y - 8),
		CFrame = CFrame.new(0, HubConfig.FLOOR_Y + 0.05, 0),
		Color = colors.FloorAccent,
		Material = Enum.Material.SmoothPlastic,
	})

	local spawnPad = makePart({
		Name = "SpawnPad",
		Parent = root,
		Size = Vector3.new(14, 0.4, 14),
		CFrame = CFrame.new(HubConfig.SPAWN.X, HubConfig.FLOOR_Y + 0.25, HubConfig.SPAWN.Z),
		Color = colors.SpawnPad,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})

	local spawnLight = Instance.new("PointLight")
	spawnLight.Color = colors.SpawnPad
	spawnLight.Brightness = 2
	spawnLight.Range = 24
	spawnLight.Parent = spawnPad

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = root

	buildPaths(root, colors)
	buildArenaGate(root, HubConfig.ZONES.ArenaGate.position, colors.ArenaGate)
	buildBeyTerminal(root, HubConfig.ZONES.BeyTerminal.position, colors.BeyTerminal)
	local _, statsLabel, leaderboardLabel = buildStatsPylon(root, HubConfig.ZONES.StatsBoard.position, colors.StatsBoard)

	for zoneId, zone in HubConfig.ZONES do
		local color = colors[zoneId] or colors.Neon
		addZoneMarker(zonesFolder, zone.id, zone.position, color, 6)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	return root, {
		statsLabel = statsLabel,
		leaderboardLabel = leaderboardLabel,
	}
end

return HubWorldBuilder
