local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addSign(parent, zone)
	local sign = Instance.new("Part")
	sign.Name = zone.id .. "Sign"
	sign.Size = Vector3.new(zone.size.X, 1, 0.4)
	sign.Position = zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	sign.Anchored = true
	sign.CanCollide = false
	sign.Material = Enum.Material.Neon
	sign.Color = zone.color
	sign.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 22
	label.Text = zone.name
	label.Parent = billboard
end

local function addZoneMarker(parent, zone)
	local marker = makePart(
		zone.id .. "Zone",
		zone.size,
		zone.position,
		zone.color,
		parent
	)
	marker.Transparency = 0.55
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.2
	light.Range = zone.size.Magnitude
	light.Parent = marker

	addSign(parent, zone)
end

local function buildLeaderboardBoard(parent, entries)
	local board = makePart(
		"LeaderboardBoard",
		Vector3.new(12, 8, 0.5),
		HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 5, -7),
		Color3.fromRGB(30, 30, 40),
		parent
	)

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build(leaderboardEntries)
	local workspace = game:GetService("Workspace")
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 2.5
	makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		Vector3.new(0, floorY, 0),
		Color3.fromRGB(45, 50, 65),
		hub
	)

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ "NorthWall", Vector3.new(halfX * 2 + wallT * 2, wallH, wallT), Vector3.new(0, wallY, halfZ + wallT * 0.5) },
		{ "SouthWall", Vector3.new(halfX * 2 + wallT * 2, wallH, wallT), Vector3.new(0, wallY, -halfZ - wallT * 0.5) },
		{ "EastWall", Vector3.new(wallT, wallH, halfZ * 2), Vector3.new(halfX + wallT * 0.5, wallY, 0) },
		{ "WestWall", Vector3.new(wallT, wallH, halfZ * 2), Vector3.new(-halfX - wallT * 0.5, wallY, 0) },
	}
	for _, wall in walls do
		makePart(wall[1], wall[2], wall[3], Color3.fromRGB(55, 60, 75), hub)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	for _, zone in HubConfig.ZONES do
		addZoneMarker(hub, zone)
	end

	buildLeaderboardBoard(hub, leaderboardEntries or {})

	return hub
end

function HubWorldBuilder.updateLeaderboard(entries)
	local hub = game:GetService("Workspace"):FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if board then board:Destroy() end
	buildLeaderboardBoard(hub, entries)
end

return HubWorldBuilder
