local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Parent = parent
	return part
end

local function addZoneMarker(zone, parent, origin)
	local platform = makePart(
		zone.id .. "_Platform",
		Vector3.new(14, 0.5, 14),
		CFrame.new(origin + zone.position + Vector3.new(0, 0.25, 0)),
		zone.color,
		parent
	)
	platform.Material = Enum.Material.Neon
	platform.Transparency = 0.35

	local pillar = makePart(
		zone.id .. "_Sign",
		Vector3.new(0.4, 6, 4),
		CFrame.new(origin + zone.position + Vector3.new(0, 3.5, 0)),
		zone.color,
		parent
	)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pillar

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	local trigger = Instance.new("Part")
	trigger.Name = zone.id
	trigger.Size = Vector3.new(HubConfig.ZONE_RADIUS * 2, 8, HubConfig.ZONE_RADIUS * 2)
	trigger.CFrame = CFrame.new(origin + zone.position + Vector3.new(0, 4, 0))
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Parent = parent

	local attrs = Instance.new("Configuration")
	attrs.Name = "ZoneData"
	local actionVal = Instance.new("StringValue")
	actionVal.Name = "action"
	actionVal.Value = zone.action
	actionVal.Parent = attrs
	local hintVal = Instance.new("StringValue")
	hintVal.Name = "hint"
	hintVal.Value = zone.hint
	hintVal.Parent = attrs
	local nameVal = Instance.new("StringValue")
	nameVal.Name = "displayName"
	nameVal.Value = zone.name
	nameVal.Parent = attrs
	attrs.Parent = trigger
end

function HubWorldBuilder.buildLeaderboardBoard(parent, origin, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if board then board:Destroy() end

	board = makePart(
		"LeaderboardBoard",
		Vector3.new(18, 10, 0.5),
		CFrame.new(origin + Vector3.new(0, 5, -52)),
		Color3.fromRGB(30, 30, 40),
		parent
	)

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.TextSize = 28
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
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

	return board
end

function HubWorldBuilder.build(origin)
	origin = origin or Vector3.zero

	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then existing:Destroy() end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color3.fromRGB(45, 50, 65),
		hub
	)
	floor.Material = Enum.Material.Slate

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallColor = Color3.fromRGB(35, 38, 50)

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart("Wall" .. i, wall[2], CFrame.new(origin + wall[1]), wallColor, hub)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		addZoneMarker(zone, zonesFolder, origin)
	end

	hub:SetAttribute("Origin", origin)
	return hub
end

return HubWorldBuilder
