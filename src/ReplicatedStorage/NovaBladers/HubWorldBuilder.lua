local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function makeLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function makeProximityPrompt(parent, actionLabel)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = actionLabel
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.createFloor(hubFolder)
	local floor = makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		HubConfig.FLOOR_CENTER,
		Color3.fromRGB(45, 50, 65),
		hubFolder
	)
	floor.Material = Enum.Material.Slate
	return floor
end

function HubWorldBuilder.createWalls(hubFolder, floor)
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hubFolder

	local floorSize = floor.Size
	local center = floor.Position
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local thick = HubConfig.WALL_THICKNESS
	local wallY = center.Y + wallH / 2
	local wallColor = Color3.fromRGB(60, 65, 80)

	local wallDefs = {
		{ "NorthWall", Vector3.new(floorSize.X + thick * 2, wallH, thick), Vector3.new(center.X, wallY, center.Z + halfZ + thick / 2) },
		{ "SouthWall", Vector3.new(floorSize.X + thick * 2, wallH, thick), Vector3.new(center.X, wallY, center.Z - halfZ - thick / 2) },
		{ "EastWall", Vector3.new(thick, wallH, floorSize.Z), Vector3.new(center.X + halfX + thick / 2, wallY, center.Z) },
		{ "WestWall", Vector3.new(thick, wallH, floorSize.Z), Vector3.new(center.X - halfX - thick / 2, wallY, center.Z) },
	}

	for _, def in wallDefs do
		makePart(def[1], def[2], def[3], wallColor, wallsFolder)
	end

	return wallsFolder
end

function HubWorldBuilder.createSpawn(hubFolder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hubFolder
	return spawn
end

function HubWorldBuilder.createZone(zoneDef, zonesFolder)
	local zone = makePart(zoneDef.id, zoneDef.size, zoneDef.position, zoneDef.color, zonesFolder)
	zone.Transparency = 0.35
	zone.Material = Enum.Material.Neon
	zone.CanCollide = false

	local marker = makePart(
		"Marker",
		Vector3.new(zoneDef.size.X * 0.6, 0.4, zoneDef.size.Z * 0.6),
		zoneDef.position - Vector3.new(0, zoneDef.size.Y / 2 - 0.2, 0),
		zoneDef.color,
		zone
	)
	marker.Transparency = 0.15
	marker.CanCollide = true
	marker.Material = Enum.Material.Marble

	makeLabel(zone, zoneDef.name, zoneDef.size.Y / 2 + 2)
	makeProximityPrompt(marker, zoneDef.actionLabel)

	local touchPart = Instance.new("Part")
	touchPart.Name = "TouchRegion"
	touchPart.Size = zoneDef.size + Vector3.new(4, 4, 4)
	touchPart.Position = zoneDef.position
	touchPart.Anchored = true
	touchPart.CanCollide = false
	touchPart.Transparency = 1
	touchPart.Parent = zone

	return zone
end

function HubWorldBuilder.createZones(hubFolder)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubFolder

	local zones = {}
	for _, zoneDef in HubConfig.ZONES do
		zones[zoneDef.id] = HubWorldBuilder.createZone(zoneDef, zonesFolder)
	end
	return zonesFolder, zones
end

function HubWorldBuilder.createLeaderboardBoard(hubFolder, hallZone)
	local board = makePart(
		"LeaderboardBoard",
		Vector3.new(12, 8, 0.5),
		hallZone.Position + Vector3.new(0, 2, -hallZone.Size.Z / 2 - 1),
		Color3.fromRGB(30, 32, 42),
		hubFolder
	)
	board.Material = Enum.Material.Metal

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 28
	list.Text = "Lade Rangliste..."
	list.Parent = surface

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "NovaHub"
	hubFolder.Parent = workspace

	local floor = HubWorldBuilder.createFloor(hubFolder)
	HubWorldBuilder.createWalls(hubFolder, floor)
	HubWorldBuilder.createSpawn(hubFolder)
	local _, zones = HubWorldBuilder.createZones(hubFolder)

	local hallZone = zones.HallOfFame
	local board = nil
	if hallZone then
		board = HubWorldBuilder.createLeaderboardBoard(hubFolder, hallZone)
	end

	return hubFolder, zones, board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	if not board then return end
	local surface = board:FindFirstChild("LeaderboardGui")
	if not surface then return end
	local list = surface:FindFirstChild("List")
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
