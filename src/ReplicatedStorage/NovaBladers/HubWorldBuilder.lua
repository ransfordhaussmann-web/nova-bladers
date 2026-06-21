local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function buildZone(parent, zone)
	local floorY = HubConfig.SPAWN_POSITION.Y - 3
	local center = Vector3.new(zone.position.X, floorY + 0.25, zone.position.Z)

	local pad = makePart({
		name = zone.id,
		parent = parent,
		size = zone.size,
		cframe = CFrame.new(center),
		color = zone.color,
		material = Enum.Material.Neon,
	})
	pad.Transparency = 0.55
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("Hint", zone.hint)

	local sign = makePart({
		name = zone.id .. "Sign",
		parent = parent,
		size = Vector3.new(zone.size.X * 0.7, 0.4, 0.4),
		cframe = CFrame.new(center + Vector3.new(0, 3.5, 0)),
		color = zone.color,
		material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return pad
end

local function buildLeaderboardBoard(parent, entries)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local part = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = boardCfg.size,
		cframe = CFrame.new(boardCfg.position),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = boardCfg.face
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -12, 1, -44)
	list.Position = UDim2.new(0, 6, 0, 40)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	if entries and #entries > 0 then
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return part
end

function HubWorldBuilder.updateLeaderboard(entries)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local surface = board:FindFirstChildWhichIsA("SurfaceGui")
	if not surface then return end
	local frame = surface:FindFirstChild("Frame")
	if not frame then return end
	local entriesLabel = frame:FindFirstChild("Entries")
	if not entriesLabel then return end

	local lines = {}
	if entries and #entries > 0 then
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	entriesLabel.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 3
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Concrete,
	})

	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ - wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallY, halfZ + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(-halfX - wallT / 2, wallY, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX + wallT / 2, wallY, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(55, 58, 68),
			material = Enum.Material.Brick,
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		parent = hub,
		size = Vector3.new(6, 1, 6),
		cframe = CFrame.new(HubConfig.SPAWN_POSITION.X, floorY + 0.5, HubConfig.SPAWN_POSITION.Z),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
	})
	spawn.Transparency = 0.7
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = false
	spawnLoc.Size = Vector3.new(6, 1, 6)
	spawnLoc.CFrame = spawn.CFrame
	spawnLoc.Transparency = 1
	spawnLoc.Duration = 0
	spawnLoc.Neutral = true
	spawnLoc.Name = "SpawnLocation"
	spawnLoc.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZone(hub, zone)
	end

	buildLeaderboardBoard(hub, leaderboardEntries)

	return hub
end

return HubWorldBuilder
