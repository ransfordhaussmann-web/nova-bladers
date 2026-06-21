local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addSign(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.fromRGB(245, 245, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function addZone(hub, zoneDef)
	local zones = hub:FindFirstChild("Zones")
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneDef.id
	zoneFolder.Parent = zones

	local platform = makePart({
		Name = "Platform",
		Parent = zoneFolder,
		Size = zoneDef.size,
		CFrame = CFrame.new(zoneDef.position),
		Color = zoneDef.color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})

	local trigger = makePart({
		Name = "Trigger",
		Parent = zoneFolder,
		Size = zoneDef.size + Vector3.new(2, 4, 2),
		CFrame = CFrame.new(zoneDef.position + Vector3.new(0, 2, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	trigger:SetAttribute("ZoneId", zoneDef.id)
	trigger:SetAttribute("Action", zoneDef.action)

	addSign(trigger, zoneDef.label .. "\n" .. zoneDef.hint, 5)

	local light = Instance.new("PointLight")
	light.Color = zoneDef.color
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = platform

	return zoneFolder, trigger
end

local function buildLeaderboardBoard(hub)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local boards = hub:FindFirstChild("LeaderboardBoards")
	if not boards then
		boards = Instance.new("Folder")
		boards.Name = "LeaderboardBoards"
		boards.Parent = hub
	end

	local board = makePart({
		Name = "HallOfFameBoard",
		Parent = boards,
		Size = boardCfg.size,
		CFrame = CFrame.new(boardCfg.position),
		Color = Color3.fromRGB(35, 38, 50),
		Material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = boardCfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(12, 52)
	list.Size = UDim2.new(1, -24, 1, -60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.Text = "Lade Rangliste..."
	list.TextWrapped = true
	list.Parent = frame

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(HubConfig.ORIGIN),
		Color = Color3.fromRGB(45, 50, 62),
		Material = Enum.Material.Slate,
	})

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2 + 0.5
	local t = HubConfig.WALL_THICKNESS

	local wallDefs = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + t, HubConfig.WALL_HEIGHT, t) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + t, HubConfig.WALL_HEIGHT, t) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(t, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(t, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for i, def in ipairs(wallDefs) do
		makePart({
			Name = "Wall" .. i,
			Parent = walls,
			Size = def[2],
			CFrame = CFrame.new(def[1]),
			Color = Color3.fromRGB(55, 60, 75),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.4
	spawn.Color = Color3.fromRGB(100, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zoneDef in pairs(HubConfig.ZONES) do
		addZone(hub, zoneDef)
	end

	buildLeaderboardBoard(hub)

	hub.PrimaryPart = floor
	hub.Parent = workspace

	return hub
end

function HubWorldBuilder.getLeaderboardGui()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local board = hub:FindFirstChild("LeaderboardBoards")
		and hub.LeaderboardBoards:FindFirstChild("HallOfFameBoard")
	if not board then return nil end
	local surface = board:FindFirstChild("BoardGui")
	return surface and surface:FindFirstChild("Content")
end

function HubWorldBuilder.formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

return HubWorldBuilder
