local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function createBillboard(parent, title, subtitle)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SignAttachment"
	attachment.Position = Vector3.new(0, 5, 0)
	attachment.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneSign"
	billboard.Size = UDim2.fromOffset(220, 72)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.fromScale(0, 0.55)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextColor3 = Color3.fromRGB(210, 220, 240)
	subtitleLabel.TextScaled = true
	subtitleLabel.Text = subtitle or ""
	subtitleLabel.Parent = billboard

	return billboard
end

local function createZone(parent, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneConfig.id
	zoneFolder.Parent = parent

	local pad = createPart({
		name = "Pad",
		parent = zoneFolder,
		size = zoneConfig.size,
		position = zoneConfig.position,
		color = zoneConfig.color,
		material = Enum.Material.Neon,
		transparency = 0.35,
	})
	pad:SetAttribute("ZoneId", zoneConfig.id)
	pad:SetAttribute("ZoneAction", zoneConfig.action)

	local frame = createPart({
		name = "Frame",
		parent = zoneFolder,
		size = Vector3.new(zoneConfig.size.X + 2, 0.4, zoneConfig.size.Z + 2),
		position = zoneConfig.position - Vector3.new(0, 0.7, 0),
		color = Color3.fromRGB(45, 50, 70),
		material = Enum.Material.Metal,
	})
	frame.CanCollide = false

	createBillboard(pad, zoneConfig.name, zoneConfig.hint)

	return zoneFolder
end

local function createWalls(parent, floorSize, floorCenter)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local height = HubConfig.WALL_HEIGHT
	local thickness = HubConfig.WALL_THICKNESS
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = parent

	local wallDefs = {
		{ name = "North", size = Vector3.new(floorSize.X + thickness * 2, height, thickness), pos = floorCenter + Vector3.new(0, height / 2, -halfZ - thickness / 2) },
		{ name = "South", size = Vector3.new(floorSize.X + thickness * 2, height, thickness), pos = floorCenter + Vector3.new(0, height / 2, halfZ + thickness / 2) },
		{ name = "West", size = Vector3.new(thickness, height, floorSize.Z), pos = floorCenter + Vector3.new(-halfX - thickness / 2, height / 2, 0) },
		{ name = "East", size = Vector3.new(thickness, height, floorSize.Z), pos = floorCenter + Vector3.new(halfX + thickness / 2, height / 2, 0) },
	}

	for _, def in wallDefs do
		createPart({
			name = def.name,
			parent = walls,
			size = def.size,
			position = def.pos,
			color = Color3.fromRGB(20, 24, 36),
			material = Enum.Material.Concrete,
		})
	end

	return walls
end

function HubWorldBuilder.updateLeaderboardBoard(boardPart, entries)
	local surface = boardPart:FindFirstChild("LeaderboardSurface")
	if not surface then return end

	local list = surface:FindFirstChild("List")
	if not list then return end

	local lines = { "🏆 Nova Liga — Top " .. HubConfig.LEADERBOARD.topCount }
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.createLeaderboardBoard(parent, zonePosition, entries)
	local boardFolder = parent:FindFirstChild("LeaderboardBoard")
	if boardFolder then
		boardFolder:Destroy()
	end

	boardFolder = Instance.new("Folder")
	boardFolder.Name = "LeaderboardBoard"
	boardFolder.Parent = parent

	local boardPos = zonePosition + HubConfig.LEADERBOARD.boardOffset
	local board = createPart({
		name = "Board",
		parent = boardFolder,
		size = HubConfig.LEADERBOARD.boardSize,
		position = boardPos,
		color = Color3.fromRGB(18, 22, 34),
		material = Enum.Material.SmoothPlastic,
	})
	board.Orientation = Vector3.new(0, 180, 0)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.GothamMedium
	list.TextColor3 = Color3.fromRGB(240, 245, 255)
	list.TextScaled = false
	list.TextSize = 28
	list.TextWrapped = true
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = surface

	HubWorldBuilder.updateLeaderboardBoard(board, entries)
	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorCfg = HubConfig.FLOOR
	createPart({
		name = "Floor",
		parent = hub,
		size = floorCfg.size,
		position = floorCfg.position,
		color = floorCfg.color,
		material = Enum.Material.Slate,
	})

	createPart({
		name = "SpawnPad",
		parent = hub,
		size = Vector3.new(10, 0.6, 10),
		position = floorCfg.position + HubConfig.SPAWN_OFFSET - Vector3.new(0, 2.3, 0),
		color = Color3.fromRGB(90, 110, 180),
		material = Enum.Material.Neon,
		transparency = 0.2,
	})

	createWalls(hub, floorCfg.size, floorCfg.position)

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zoneConfig in HubConfig.ZONES do
		createZone(zones, zoneConfig)
	end

	local hallZone = HubConfig.ZONES.HallOfFame
	HubWorldBuilder.createLeaderboardBoard(hub, hallZone.position, {})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = floorCfg.position + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	return hub
end

function HubWorldBuilder.getHubSpawnCFrame()
	local floorCenter = HubConfig.FLOOR.position + HubConfig.SPAWN_OFFSET
	return CFrame.new(floorCenter)
end

return HubWorldBuilder
