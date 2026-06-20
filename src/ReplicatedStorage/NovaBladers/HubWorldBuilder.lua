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

local function addSign(parent, text, offset, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 3, 0.4),
		Position = offset,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function addZoneTrigger(zoneFolder, zoneDef, hubOrigin)
	local trigger = makePart({
		Name = "Trigger",
		Size = zoneDef.size,
		Position = hubOrigin + zoneDef.position + Vector3.new(0, zoneDef.size.Y * 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = zoneFolder,
	})
	trigger:SetAttribute("ZoneId", zoneDef.id)
	return trigger
end

local function addZonePlatform(zoneFolder, zoneDef, hubOrigin)
	local platform = makePart({
		Name = "Platform",
		Size = Vector3.new(zoneDef.size.X, 0.6, zoneDef.size.Z),
		Position = hubOrigin + zoneDef.position + Vector3.new(0, 0.3, 0),
		Color = zoneDef.color,
		Material = Enum.Material.SmoothPlastic,
		Parent = zoneFolder,
	})

	local ring = makePart({
		Name = "Ring",
		Size = Vector3.new(zoneDef.size.X + 1, 0.2, zoneDef.size.Z + 1),
		Position = platform.Position + Vector3.new(0, 0.35, 0),
		Color = zoneDef.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = zoneFolder,
	})

	addSign(zoneFolder, zoneDef.name, platform.Position + Vector3.new(0, 5, -(zoneDef.size.Z * 0.5 + 1)), zoneDef.color)
	addZoneTrigger(zoneFolder, zoneDef, hubOrigin)

	return platform, ring
end

function HubWorldBuilder.buildLeaderboardBoard(parent, hubOrigin, zoneDef)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 7, 0.5),
		Position = hubOrigin + zoneDef.position + Vector3.new(0, 5, 2),
		Color = Color3.fromRGB(25, 25, 35),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Top Nova Bladers"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, 55)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = false
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.Gotham
	list.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local origin = Vector3.new(0, 0, 0)
	hub:SetAttribute("Origin", origin)

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0),
		Color = HubConfig.THEME.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wallData in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wallData[2],
			Position = origin + wallData[1],
			Color = HubConfig.THEME.Wall,
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = HubConfig.THEME.Accent
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneDef in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zoneDef.id
		zoneFolder.Parent = zonesFolder
		addZonePlatform(zoneFolder, zoneDef, origin)

		if zoneDef.id == "HallOfFame" then
			HubWorldBuilder.buildLeaderboardBoard(zoneFolder, origin, zoneDef)
		elseif zoneDef.id == "ArenaGate" then
			local gate = makePart({
				Name = "GateFrame",
				Size = Vector3.new(12, 9, 1.2),
				Position = origin + zoneDef.position + Vector3.new(0, 5, -zoneDef.size.Z * 0.5),
				Color = zoneDef.color,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				CanCollide = false,
				Parent = zoneFolder,
			})
			gate.Name = "GateFrame"
		end
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 60
	light.Parent = floor

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if hub and hub:FindFirstChild("HubSpawn") then
		return hub.HubSpawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if not hub then return end

	local zone = hub:FindFirstChild("Zones") and hub.Zones:FindFirstChild("HallOfFame")
	local board = zone and zone:FindFirstChild("LeaderboardBoard")
	local gui = board and board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
