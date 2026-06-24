local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Name = props.name or "Part"
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	local anchor = makePart({
		name = "SignAnchor",
		size = Vector3.new(1, 1, 1),
		position = position,
		transparency = 1,
		canCollide = false,
		parent = parent,
	})
	billboard.Adornee = anchor
	return anchor
end

local function buildWalls(folder, floorSize, floorPos)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = floorPos.Y + HubConfig.WALL_HEIGHT / 2
	local wallThickness = 2

	local walls = {
		{ size = Vector3.new(floorSize.X + 4, HubConfig.WALL_HEIGHT, wallThickness), pos = Vector3.new(floorPos.X, y, floorPos.Z - halfZ - 1) },
		{ size = Vector3.new(floorSize.X + 4, HubConfig.WALL_HEIGHT, wallThickness), pos = Vector3.new(floorPos.X, y, floorPos.Z + halfZ + 1) },
		{ size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z + 4), pos = Vector3.new(floorPos.X - halfX - 1, y, floorPos.Z) },
		{ size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z + 4), pos = Vector3.new(floorPos.X + halfX + 1, y, floorPos.Z) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = folder

	for i, spec in walls do
		makePart({
			name = "Wall" .. i,
			size = spec.size,
			position = spec.pos,
			color = Color3.fromRGB(45, 48, 58),
			material = Enum.Material.Concrete,
			parent = wallsFolder,
		})
	end
end

local function buildZone(folder, zoneConfig)
	local zonesFolder = folder:FindFirstChild("Zones") or Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = folder

	local zonePart = makePart({
		name = zoneConfig.id,
		size = zoneConfig.size,
		position = zoneConfig.position,
		color = zoneConfig.color,
		transparency = 0.55,
		material = Enum.Material.Neon,
		parent = zonesFolder,
	})
	zonePart:SetAttribute("ZoneId", zoneConfig.id)
	zonePart:SetAttribute("ZoneAction", zoneConfig.action)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.promptText
	prompt.ObjectText = zoneConfig.label
	prompt.MaxActivationDistance = HubConfig.PROXIMITY_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = zonePart

	makeSign(zonesFolder, zoneConfig.label, zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2, 0), zoneConfig.color)

	return zonePart
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local boardConfig = HubConfig.LEADERBOARD_BOARD
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		size = boardConfig.size,
		position = boardConfig.position,
		color = Color3.fromRGB(30, 30, 40),
		material = Enum.Material.Slate,
		parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = boardConfig.face
	surface.CanvasSize = Vector2.new(400, 260)
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 210, 60)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Position = UDim2.fromOffset(8, 40)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 16
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Parent = surface

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

function HubWorldBuilder.build(leaderboardEntries)
	local workspace = game:GetService("Workspace")
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(55, 58, 68),
		material = Enum.Material.Grass,
		parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	buildWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.FLOOR_POSITION)

	for _, zoneConfig in HubConfig.ZONES do
		buildZone(hub, zoneConfig)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, leaderboardEntries)

	local light = Instance.new("PointLight")
	light.Brightness = 0.4
	light.Range = 60
	light.Parent = floor

	return hub
end

return HubWorldBuilder
