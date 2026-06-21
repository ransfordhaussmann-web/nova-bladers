local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(60, 60, 70)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.displayName
	label.Parent = billboard
end

function HubWorldBuilder.buildFloor(hub, origin)
	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR.SIZE,
		CFrame = CFrame.new(origin + Vector3.new(0, HubConfig.FLOOR.SIZE.Y / 2, 0)),
		Color = HubConfig.FLOOR.COLOR,
		Material = HubConfig.FLOOR.MATERIAL,
	})
	floor:SetAttribute("HubSurface", true)
	return floor
end

function HubWorldBuilder.buildWalls(hub, origin)
	local floorSize = HubConfig.FLOOR.SIZE
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local thick = HubConfig.WALL_THICKNESS
	local y = origin.Y + wallH / 2 + HubConfig.FLOOR.SIZE.Y

	local walls = {
		{ name = "WallNorth", pos = Vector3.new(0, y, -halfZ), size = Vector3.new(floorSize.X, wallH, thick) },
		{ name = "WallSouth", pos = Vector3.new(0, y, halfZ), size = Vector3.new(floorSize.X, wallH, thick) },
		{ name = "WallWest", pos = Vector3.new(-halfX, y, 0), size = Vector3.new(thick, wallH, floorSize.Z) },
		{ name = "WallEast", pos = Vector3.new(halfX, y, 0), size = Vector3.new(thick, wallH, floorSize.Z) },
	}

	for _, wall in walls do
		makePart({
			Name = wall.name,
			Parent = hub,
			Size = wall.size,
			CFrame = CFrame.new(origin + wall.pos),
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
		})
	end
end

function HubWorldBuilder.buildSpawn(hub, origin)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Color = Color3.fromRGB(100, 180, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub
	return spawn
end

function HubWorldBuilder.buildZone(hub, origin, zoneKey, zone)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneKey
	zoneFolder.Parent = hub

	local pad = makePart({
		Name = "Pad",
		Parent = zoneFolder,
		Size = zone.size,
		CFrame = CFrame.new(origin + zone.position),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("ZoneAction", zone.action)

	local frame = makePart({
		Name = "Frame",
		Parent = zoneFolder,
		Size = zone.size + Vector3.new(0.4, 0.4, 0.4),
		CFrame = CFrame.new(origin + zone.position),
		Color = zone.color,
		Material = Enum.Material.Metal,
		Transparency = 0.2,
		CanCollide = true,
	})

	addZoneLabel(pad, zone)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.displayName
	prompt.ObjectText = zone.hint
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(zone.size.X, zone.size.Z) * 0.6
	prompt.Parent = pad

	return zoneFolder
end

function HubWorldBuilder.buildLeaderboardBoard(hub, origin)
	local cfg = HubConfig.LEADERBOARD
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = hub,
		Size = cfg.size,
		CFrame = CFrame.new(origin + cfg.position),
		Color = Color3.fromRGB(25, 25, 35),
		Material = Enum.Material.SmoothPlastic,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = cfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	title.BackgroundTransparency = 0.2
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 22
	title.Text = "🏆 Nova Liga"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 18
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.Parent = surface

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN
	HubWorldBuilder.buildFloor(hub, origin)
	HubWorldBuilder.buildWalls(hub, origin)
	HubWorldBuilder.buildSpawn(hub, origin)

	for zoneKey, zone in HubConfig.ZONES do
		HubWorldBuilder.buildZone(hub, origin, zoneKey, zone)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, origin)

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET + Vector3.new(0, 2, 0))
end

function HubWorldBuilder.updateLeaderboard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then return end

	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local gui = board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("Entries")
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
