local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(10, 4, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 8, 0)),
		Color = color,
		Material = Enum.Material.Neon,
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
end

local function buildZone(parent, zone)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.id
	zoneFolder.Parent = parent

	makePart({
		Name = "Platform",
		Parent = zoneFolder,
		Size = Vector3.new(zone.size.X, 1, zone.size.Z),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 0.5, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	}):SetAttribute("ZoneId", zone.id)

	makePart({
		Name = "Trigger",
		Parent = zoneFolder,
		Size = zone.size,
		CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5, 0)),
		Transparency = 1,
		CanCollide = false,
	}):SetAttribute("ZoneId", zone.id)

	addSign(zoneFolder, zone.name, zone.position, zone.color)

	return zoneFolder
end

local function buildLeaderboardBoard(parent, zone)
	local boardPart = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Size = Vector3.new(12, 8, 0.5),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 5, -zone.size.Z * 0.5 - 1)),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = boardPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, 60)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = false
	list.TextSize = 28
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.Gotham
	list.Parent = gui

	return boardPart
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Concrete,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH * 0.5, halfZ + wallT * 0.5), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallH * 0.5, -halfZ - wallT * 0.5), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(halfX + wallT * 0.5, wallH * 0.5, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX - wallT * 0.5, wallH * 0.5, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(50, 54, 68),
			Material = Enum.Material.Brick,
		})
	end

	makePart({
		Name = "SpawnPad",
		Parent = hub,
		Size = Vector3.new(8, 0.5, 8),
		CFrame = CFrame.new(HubConfig.SPAWN - Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	addSign(hub, "Nova Bladers Hub", HubConfig.SPAWN - Vector3.new(0, 1, 8), Color3.fromRGB(120, 180, 255))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local leaderboardBoard
	for _, zone in HubConfig.ZONES do
		buildZone(zonesFolder, zone)
		if zone.id == "HallOfFame" then
			leaderboardBoard = buildLeaderboardBoard(zonesFolder, zone)
		end
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 40
	light.Parent = floor

	return hub, leaderboardBoard
end

return HubWorldBuilder
