local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(45, 50, 65)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addZoneLabel(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function buildLeaderboardBoard(parent, zone)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(zone.size.X, zone.size.Y * 0.8, 0.4),
		position = zone.position + Vector3.new(0, zone.size.Y * 0.3, -zone.size.Z * 0.5 - 0.5),
		color = Color3.fromRGB(30, 30, 40),
		material = Enum.Material.Neon,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = zone.color
	title.TextScaled = true
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -48)
	list.Position = UDim2.fromOffset(8, 44)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 18
	list.TextWrapped = true
	list.Text = "Lade Rangliste..."
	list.Parent = frame

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

	local floorY = HubConfig.SPAWN_POSITION.Y - 3
	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY, 0),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ name = "WallNorth", pos = Vector3.new(0, wallY, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ name = "WallSouth", pos = Vector3.new(0, wallY, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ name = "WallWest", pos = Vector3.new(-halfX, wallY, 0), size = Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallEast", pos = Vector3.new(halfX, wallY, 0), size = Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(50, 55, 72),
			material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			canCollide = false,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("Action", zone.action)
		addZoneLabel(marker, zone.name, zone.color)

		if zone.id == "hallOfFame" then
			buildLeaderboardBoard(hub, zone)
		end
	end

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

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then return end

	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then return end

	local content = surface:FindFirstChild("Content")
	local list = content and content:FindFirstChild("Entries")
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
