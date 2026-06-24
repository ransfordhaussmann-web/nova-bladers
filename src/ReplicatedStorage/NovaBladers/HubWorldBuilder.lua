local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function makeLabel(parent, text, size, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = size or UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	return billboard
end

local function makeZoneMarker(parent, zone)
	local marker = makePart({
		Name = zone.id,
		Parent = parent,
		Position = zone.position,
		Size = zone.size,
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	marker.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = "Nova Bladers"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = marker

	local attributes = marker
	attributes:SetAttribute("zoneId", zone.id)
	attributes:SetAttribute("action", zone.action)
	attributes:SetAttribute("hint", zone.hint)

	makeLabel(marker, zone.name, UDim2.fromOffset(220, 44), Vector3.new(0, zone.size.Y / 2 + 2, 0))

	return marker
end

local function buildWalls(parent, floorSize, floorPos, wallHeight)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = floorPos.Y + wallHeight / 2

	local walls = {
		{ Vector3.new(floorPos.X, y, floorPos.Z - halfZ), Vector3.new(floorSize.X, wallHeight, 1) },
		{ Vector3.new(floorPos.X, y, floorPos.Z + halfZ), Vector3.new(floorSize.X, wallHeight, 1) },
		{ Vector3.new(floorPos.X - halfX, y, floorPos.Z), Vector3.new(1, wallHeight, floorSize.Z) },
		{ Vector3.new(floorPos.X + halfX, y, floorPos.Z), Vector3.new(1, wallHeight, floorSize.Z) },
	}

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = parent,
			Position = wall[1],
			Size = wall[2],
			Color = Color3.fromRGB(45, 50, 65),
			Material = Enum.Material.Concrete,
		})
	end
end

local function buildLeaderboardBoard(parent, entries)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Position = boardCfg.position,
		Size = boardCfg.size,
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = boardCfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 28
	list.TextWrapped = true
	list.Parent = frame

	HubWorldBuilder.updateLeaderboardBoard(board, entries or {})
	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then return end
	local frame = surface:FindFirstChild("Frame")
	if not frame then return end
	local list = frame:FindFirstChild("Entries")
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

function HubWorldBuilder.build(workspace, entries)
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Position = HubConfig.FLOOR_POSITION,
		Size = HubConfig.FLOOR_SIZE,
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 1.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	buildWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.FLOOR_POSITION, HubConfig.WALL_HEIGHT)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in pairs(HubConfig.ZONES) do
		makeZoneMarker(zonesFolder, zone)
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 40
	lighting.Parent = floor

	buildLeaderboardBoard(hub, entries)

	return hub
end

return HubWorldBuilder
