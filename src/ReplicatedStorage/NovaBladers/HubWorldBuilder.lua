local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function createLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	return billboard
end

function HubWorldBuilder.updateLeaderboardBoard(boardPart, entries)
	local surface = boardPart:FindFirstChild("LeaderboardSurface")
	if not surface then return end

	local label = surface:FindFirstChild("List")
	if not label then return end

	local lines = { "🏆 Nova Liga — Top 5" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local zone = HubConfig.ZONES.HallOfFame
	local board = createPart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(12, 8, 0.5),
		Position = zone.position + Vector3.new(0, 4, -zone.size.Z / 2 - 1),
		Color = Color3.fromRGB(30, 30, 40),
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(600, 400)
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "List"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 28
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Parent = surface

	HubWorldBuilder.updateLeaderboardBoard(board, entries)
	return board
end

function HubWorldBuilder.buildZone(parent, zoneConfig)
	local zone = createPart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		Position = zoneConfig.position,
		Color = zoneConfig.color,
		Transparency = 0.65,
		CanCollide = false,
		CanTouch = true,
		Parent = parent,
	})
	zone:SetAttribute("ZoneId", zoneConfig.id)
	zone:SetAttribute("ZoneAction", zoneConfig.action)
	createLabel(zone, zoneConfig.name, zoneConfig.size.Y / 2 + 2)
	return zone
end

function HubWorldBuilder.build(hubFolder, leaderboardEntries)
	hubFolder:ClearAllChildren()

	local floor = createPart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, HubConfig.FLOOR_Y, 0),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
		Parent = hubFolder,
	})

	local spawn = createPart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = HubConfig.SPAWN - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(100, 180, 255),
		Transparency = 0.4,
		CanCollide = false,
		Parent = hubFolder,
	})
	createLabel(spawn, "Nova Hub", 3)

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.FLOOR_Y + HubConfig.WALL_HEIGHT / 2
	local wallThickness = 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}
	for index, wallData in walls do
		createPart({
			Name = "Wall" .. index,
			Position = wallData[1],
			Size = wallData[2],
			Color = Color3.fromRGB(35, 38, 48),
			Material = Enum.Material.Concrete,
			Parent = hubFolder,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubFolder

	for _, zoneConfig in pairs(HubConfig.ZONES) do
		HubWorldBuilder.buildZone(zonesFolder, zoneConfig)
	end

	HubWorldBuilder.buildLeaderboardBoard(hubFolder, leaderboardEntries or {})

	return hubFolder, floor
end

function HubWorldBuilder.getOrCreateFolder()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = HubConfig.HUB_FOLDER
	folder.Parent = workspace
	return folder
end

return HubWorldBuilder
