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
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function createFloor(parent)
	makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(HubConfig.FLOOR_CENTER),
		Color = Color3.fromRGB(32, 34, 42),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

local function createWalls(parent)
	local floor = HubConfig.FLOOR_SIZE
	local center = HubConfig.FLOOR_CENTER
	local h = HubConfig.WALL_HEIGHT
	local wallY = center.Y + h / 2

	local specs = {
		{ name = "WallNorth", size = Vector3.new(floor.X, h, 2), pos = Vector3.new(center.X, wallY, center.Z - floor.Z / 2) },
		{ name = "WallSouth", size = Vector3.new(floor.X, h, 2), pos = Vector3.new(center.X, wallY, center.Z + floor.Z / 2) },
		{ name = "WallWest", size = Vector3.new(2, h, floor.Z), pos = Vector3.new(center.X - floor.X / 2, wallY, center.Z) },
		{ name = "WallEast", size = Vector3.new(2, h, floor.Z), pos = Vector3.new(center.X + floor.X / 2, wallY, center.Z) },
	}

	for _, spec in specs do
		makePart({
			Name = spec.name,
			Size = spec.size,
			CFrame = CFrame.new(spec.pos),
			Color = Color3.fromRGB(55, 58, 72),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end
end

local function createZoneLabel(parent, zone)
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

local function createZones(parent)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = parent

	for _, zone in HubConfig.ZONES do
		local trigger = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.65,
			CanCollide = false,
			Parent = zonesFolder,
		})
		trigger:SetAttribute("ZoneId", zone.id)
		trigger:SetAttribute("ZoneAction", zone.action)
		trigger:SetAttribute("ZoneHint", zone.hint)
		trigger:SetAttribute("ZoneName", zone.name)
		createZoneLabel(trigger, zone)
	end

	return zonesFolder
end

local function createSpawn(parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
	return spawn
end

local function createLeaderboardBoard(parent, zonesFolder)
	local hallZone = zonesFolder:FindFirstChild("HallOfFame")
	if not hallZone then
		return
	end

	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 7, 0.5),
		CFrame = hallZone.CFrame * CFrame.new(0, 2, -hallZone.Size.Z / 2 - 1),
		Color = Color3.fromRGB(24, 26, 34),
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.new(0, 10, 0, 60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.Text = "Lade Rangliste..."
	list.Parent = frame

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.FOLDER_NAME
	hub.Parent = workspace

	createFloor(hub)
	createWalls(hub)
	local zones = createZones(hub)
	createSpawn(hub)
	createLeaderboardBoard(hub, zones)

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 40
	lighting.Parent = hub:FindFirstChild("Floor")

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.FOLDER_NAME)
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then return end
	local list = surface.Frame:FindFirstChild("Entries")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

return HubWorldBuilder
