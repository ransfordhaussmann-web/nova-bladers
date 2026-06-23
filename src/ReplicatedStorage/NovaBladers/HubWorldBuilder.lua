local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(40, 44, 52)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeZonePad(parent, zoneKey, zone)
	local pad = makePart({
		parent = parent,
		name = "Zone_" .. zoneKey,
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		cframe = CFrame.new(zone.center.X, zone.center.Y - 0.3, zone.center.Z),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.55,
		canCollide = false,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("ZoneKey", zoneKey)

	local labelPart = makePart({
		parent = pad,
		name = "Label",
		size = Vector3.new(1, 1, 1),
		cframe = pad.CFrame * CFrame.new(0, 4, 0),
		transparency = 1,
		canCollide = false,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = labelPart

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 22
	text.TextColor3 = zone.color
	text.TextStrokeTransparency = 0.5
	text.Text = zone.label
	text.Parent = billboard

	return pad
end

local function makeWalls(parent, floorSize, floorCenter, wallHeight)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = floorCenter.Y + wallHeight / 2

	local walls = {
		{ size = Vector3.new(floorSize.X, wallHeight, 2), pos = Vector3.new(floorCenter.X, y, floorCenter.Z + halfZ) },
		{ size = Vector3.new(floorSize.X, wallHeight, 2), pos = Vector3.new(floorCenter.X, y, floorCenter.Z - halfZ) },
		{ size = Vector3.new(2, wallHeight, floorSize.Z), pos = Vector3.new(floorCenter.X + halfX, y, floorCenter.Z) },
		{ size = Vector3.new(2, wallHeight, floorSize.Z), pos = Vector3.new(floorCenter.X - halfX, y, floorCenter.Z) },
	}

	for i, wall in walls do
		makePart({
			parent = parent,
			name = "Wall" .. i,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(30, 34, 42),
			material = Enum.Material.Concrete,
		})
	end
end

local function makeSpawnMarker(parent)
	local spawn = makePart({
		parent = parent,
		name = "SpawnMarker",
		size = Vector3.new(6, 0.2, 6),
		cframe = CFrame.new(HubConfig.SPAWN.X, 0.6, HubConfig.SPAWN.Z),
		color = Color3.fromRGB(120, 200, 255),
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
	})

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 200, 255)
	light.Brightness = 1
	light.Range = 12
	light.Parent = spawn
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local existing = parent:FindFirstChild("LeaderboardBoard")

	local board = existing
	if not board then
		board = makePart({
			parent = parent,
			name = "LeaderboardBoard",
			size = boardCfg.partSize,
			cframe = boardCfg.partCFrame,
			color = Color3.fromRGB(20, 22, 30),
			material = Enum.Material.Metal,
		})
	end

	local surface = board:FindFirstChild("LeaderboardGui")
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Name = "LeaderboardGui"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 40
		surface.Parent = board
	end

	local frame = surface:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
		frame.BorderSizePixel = 0
		frame.Parent = surface

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 48)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 28
		title.TextColor3 = Color3.fromRGB(255, 200, 60)
		title.Text = "🏆 Ruhmeshalle"
		title.Parent = frame

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.new(0, 12, 0, 52)
		list.Size = UDim2.new(1, -24, 1, -60)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextSize = 22
		list.TextColor3 = Color3.fromRGB(230, 230, 240)
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextWrapped = true
		list.Parent = frame
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	frame.List.Text = table.concat(lines, "\n")

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

	makePart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(HubConfig.FLOOR_CENTER),
		color = Color3.fromRGB(50, 54, 62),
		material = Enum.Material.Slate,
	})

	makeWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.FLOOR_CENTER, HubConfig.WALL_HEIGHT)
	makeSpawnMarker(hub)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneKey, zone in HubConfig.ZONES do
		makeZonePad(zonesFolder, zoneKey, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, {})

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "HubSpawn"
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.CFrame = CFrame.new(HubConfig.SPAWN)
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Transparency = 1
	spawnLocation.Duration = 0
	spawnLocation.Neutral = true
	spawnLocation.Parent = hub

	return hub
end

return HubWorldBuilder
