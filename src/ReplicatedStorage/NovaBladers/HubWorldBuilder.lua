local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addSign(parent, zone)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(8, 4, 0.5),
		Position = zone.position + Vector3.new(0, zone.size.Y * 0.5 + 3, -zone.size.Z * 0.5 - 1),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = zone.name
	label.Parent = billboard
end

local function addZoneTrigger(parent, zone)
	local trigger = makePart({
		Name = "Trigger",
		Size = zone.size,
		Position = zone.position + Vector3.new(0, zone.size.Y * 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		Parent = parent,
	})
	trigger:SetAttribute("ZoneId", zone.id)
end

local function addZonePlatform(parent, zone)
	local platform = makePart({
		Name = "Platform",
		Size = Vector3.new(zone.size.X, 1, zone.size.Z),
		Position = zone.position + Vector3.new(0, 0.5, 0),
		Color = zone.color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local ring = makePart({
		Name = "Ring",
		Size = Vector3.new(zone.size.X + 2, 0.3, zone.size.Z + 2),
		Position = zone.position + Vector3.new(0, 0.15, 0),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		Parent = parent,
	})

	addSign(parent, zone)
	addZoneTrigger(parent, zone)

	return platform
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(12, 8, 0.5),
		Position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 5, 6),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 80)
	title.TextScaled = true
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -60)
	list.Position = UDim2.fromOffset(10, 55)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 22
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	end
	list.Text = table.concat(lines, "\n")

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
	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(floorSize.X, 1, floorSize.Y),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local wallThickness = 2
	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Y * 0.5
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Vector3.new(floorSize.X + wallThickness, wallH, wallThickness), Vector3.new(0, wallH * 0.5, -halfZ) },
		{ Vector3.new(floorSize.X + wallThickness, wallH, wallThickness), Vector3.new(0, wallH * 0.5, halfZ) },
		{ Vector3.new(wallThickness, wallH, floorSize.Y), Vector3.new(-halfX, wallH * 0.5, 0) },
		{ Vector3.new(wallThickness, wallH, floorSize.Y), Vector3.new(halfX, wallH * 0.5, 0) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wall[1],
			Position = wall[2],
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
			Parent = wallsFolder,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(100, 180, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = zonesFolder
		addZonePlatform(zoneFolder, zone)
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.5
	lighting.Range = 40
	lighting.Parent = floor

	return hub
end

return HubWorldBuilder
