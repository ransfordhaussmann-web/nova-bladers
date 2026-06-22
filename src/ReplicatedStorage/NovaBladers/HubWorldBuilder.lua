local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function buildWalls(folder, floorSize, wallHeight)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = floorSize.Y / 2 + wallHeight / 2
	local wallColor = Color3.fromRGB(45, 50, 65)

	local walls = {
		{ Vector3.new(0, y, halfZ + 1), Vector3.new(floorSize.X + 2, wallHeight, 2) },
		{ Vector3.new(0, y, -halfZ - 1), Vector3.new(floorSize.X + 2, wallHeight, 2) },
		{ Vector3.new(halfX + 1, y, 0), Vector3.new(2, wallHeight, floorSize.Z + 2) },
		{ Vector3.new(-halfX - 1, y, 0), Vector3.new(2, wallHeight, floorSize.Z + 2) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = folder,
			position = wall[1],
			size = wall[2],
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end
end

local function buildZone(folder, zone)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.id
	zoneFolder.Parent = folder

	local platform = makePart({
		name = "Platform",
		parent = zoneFolder,
		position = zone.position - Vector3.new(0, zone.size.Y / 2 - 0.5, 0),
		size = Vector3.new(zone.size.X, 1, zone.size.Z),
		color = zone.color,
		material = Enum.Material.Neon,
	})

	local marker = makePart({
		name = "Marker",
		parent = zoneFolder,
		position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
		size = Vector3.new(zone.size.X * 0.6, 0.4, zone.size.Z * 0.6),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.3,
		canCollide = false,
	})

	local sign = makePart({
		name = "Sign",
		parent = zoneFolder,
		position = zone.position + Vector3.new(0, 3, 0),
		size = Vector3.new(zone.size.X, 2, 0.2),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = surface

	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = zone.size
	trigger.Position = zone.position
	trigger.Parent = zoneFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = zone.hint
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(zone.size.X, zone.size.Z) * 0.6
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	return zoneFolder, platform, marker, trigger
end

function HubWorldBuilder.buildHallOfFameBoard(parent, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		position = Vector3.new(35, 6, -4),
		size = Vector3.new(10, 8, 0.4),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 8, 0, 40)
	list.Size = UDim2.new(1, -16, 1, -48)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = surface

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

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	makePart({
		name = "Floor",
		parent = hub,
		position = HubConfig.FLOOR_CENTER,
		size = HubConfig.FLOOR_SIZE,
		color = Color3.fromRGB(55, 58, 72),
		material = Enum.Material.Slate,
	})

	buildWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.WALL_HEIGHT)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 1.5, 0)
	spawn.Color = Color3.fromRGB(100, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZone(zonesFolder, zone)
	end

	local hallFolder = zonesFolder:FindFirstChild("hall_of_fame")
	if hallFolder then
		HubWorldBuilder.buildHallOfFameBoard(hallFolder, {})
	end

	return hub
end

return HubWorldBuilder
