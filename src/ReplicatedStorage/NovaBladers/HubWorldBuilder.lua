local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(45, 50, 65)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "HubPart"
	part.Parent = props.Parent
	return part
end

local function createZoneMarker(parent, zone)
	local marker = Instance.new("Part")
	marker.Name = "Zone_" .. zone.id
	marker.Anchored = true
	marker.CanCollide = false
	marker.Transparency = 0.85
	marker.Size = zone.size
	marker.Position = zone.position + Vector3.new(0, zone.size.Y / 2, 0)
	marker.Color = Color3.fromRGB(100, 180, 255)
	marker.Material = Enum.Material.Neon
	marker.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	return marker
end

local function createLeaderboardBoard(parent, entries)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 0.5),
		Position = HubConfig.ZONES[3].position + Vector3.new(0, 5, -6),
		Color = Color3.fromRGB(30, 35, 50),
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(400, 320)
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Top Spieler"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(0, 44)
	list.Size = UDim2.new(1, 0, 1, -44)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = surface

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 3
	local floorCenter = Vector3.new(0, floorY, 0)

	makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = floorCenter,
		Color = Color3.fromRGB(55, 60, 75),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = floorY + HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			Position = wall[1],
			Color = Color3.fromRGB(40, 45, 58),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZoneMarker(zonesFolder, zone)
	end

	createLeaderboardBoard(hub, leaderboardEntries or {})

	local sign = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(16, 4, 1),
		Position = Vector3.new(0, floorY + 6, -30),
		Color = Color3.fromRGB(80, 120, 255),
		Material = Enum.Material.Neon,
		Parent = hub,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "NOVA BLADERS"
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBlack
	signLabel.Parent = signGui

	return hub
end

function HubWorldBuilder.updateLeaderboard(hub, entries)
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then return end
	local list = surface:FindFirstChild("Entries")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

return HubWorldBuilder
