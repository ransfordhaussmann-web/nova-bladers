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

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard
end

local function buildLeaderboardBoard(parent, zone)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(12, 8, 0.5),
		Position = zone.position + Vector3.new(0, 5, -zone.size.Z / 2 - 1),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextSize = 22
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 44)
	list.Size = UDim2.new(1, 0, 1, -44)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 16
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.Parent = surface
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), Position = Vector3.new(0, wallY, -halfZ) },
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), Position = Vector3.new(0, wallY, halfZ) },
		{ Size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallY, 0) },
		{ Size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallY, 0) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(35, 35, 45),
			Material = Enum.Material.Concrete,
			Parent = wallsFolder,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local platform = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			Parent = zonesFolder,
		})
		platform:SetAttribute("ZoneId", zone.id)

		local marker = makePart({
			Name = "Marker",
			Size = Vector3.new(zone.size.X * 0.6, 0.4, zone.size.Z * 0.6),
			Position = zone.position - Vector3.new(0, zone.size.Y / 2 - 0.2, 0),
			Color = zone.color,
			Material = Enum.Material.SmoothPlastic,
			Parent = platform,
		})

		addZoneLabel(platform, zone)

		if zone.id == "HallOfFame" then
			buildLeaderboardBoard(hub, zone)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN - Vector3.new(0, 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
