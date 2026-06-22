local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(40, 44, 56)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	subLabel.Text = subtitle or ""
	subLabel.Parent = gui
end

local function buildZoneMarker(parent, zone)
	local marker = makePart({
		name = zone.id,
		parent = parent,
		size = Vector3.new(zone.radius * 1.6, 0.4, zone.radius * 1.6),
		position = zone.position + Vector3.new(0, 0.7, 0),
		color = zone.color,
		material = Enum.Material.Neon,
	})
	marker.Transparency = 0.35

	local ring = makePart({
		name = zone.id .. "Ring",
		parent = parent,
		size = Vector3.new(zone.radius * 2, 0.15, zone.radius * 2),
		position = zone.position + Vector3.new(0, 0.2, 0),
		color = zone.color,
		material = Enum.Material.Glass,
	})
	ring.Transparency = 0.6

	local pillar = makePart({
		name = zone.id .. "Pillar",
		parent = parent,
		size = Vector3.new(1.2, 8, 1.2),
		position = zone.position + Vector3.new(0, 4.5, 0),
		color = zone.color,
		material = Enum.Material.Metal,
	})

	addBillboard(pillar, zone.name, zone.hint, zone.color)

	return marker
end

local function buildLeaderboardBoard(parent, zone)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(14, 10, 0.5),
		position = zone.position + Vector3.new(0, 6, -8),
		color = Color3.fromRGB(30, 32, 42),
		material = Enum.Material.Slate,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.TextWrapped = true
	list.Parent = frame

	return board
end

function HubWorldBuilder.build(origin)
	origin = origin or Vector3.zero

	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		position = origin + Vector3.new(0, -0.5, 0),
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Concrete,
	})

	local wallHeight = HubConfig.WALL_HEIGHT
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallThickness = 2

	local walls = {
		{ size = Vector3.new(floorSize.X, wallHeight, wallThickness), pos = Vector3.new(0, wallHeight / 2, halfZ) },
		{ size = Vector3.new(floorSize.X, wallHeight, wallThickness), pos = Vector3.new(0, wallHeight / 2, -halfZ) },
		{ size = Vector3.new(wallThickness, wallHeight, floorSize.Z), pos = Vector3.new(halfX, wallHeight / 2, 0) },
		{ size = Vector3.new(wallThickness, wallHeight, floorSize.Z), pos = Vector3.new(-halfX, wallHeight / 2, 0) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall.size,
			position = origin + wall.pos,
			color = Color3.fromRGB(50, 54, 68),
			material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneData = table.clone(zone)
		zoneData.position = origin + zone.position
		buildZoneMarker(zonesFolder, zoneData)
	end

	local hallZone = HubConfig.ZONES.HallOfFame
	local hallPos = origin + hallZone.position
	buildLeaderboardBoard(hub, { position = hallPos })

	local sign = makePart({
		name = "WelcomeSign",
		parent = hub,
		size = Vector3.new(20, 4, 1),
		position = origin + Vector3.new(0, 6, -halfZ + 4),
		color = Color3.fromRGB(60, 80, 200),
		material = Enum.Material.Neon,
	})
	addBillboard(sign, "Nova Bladers", "Wähle eine Zone und starte deinen Kampf", Color3.fromRGB(140, 180, 255))

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then return end

	local frame = surface:FindFirstChildOfClass("Frame")
	if not frame then return end

	local list = frame:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
