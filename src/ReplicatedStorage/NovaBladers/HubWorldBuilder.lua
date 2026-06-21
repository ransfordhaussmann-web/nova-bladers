local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 50, 65)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function createZoneLabel(zonePart, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 20
	label.Text = zone.name
	label.Parent = billboard
end

local function createProximityPrompt(zonePart, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(zone.size.X, zone.size.Z) * 0.55
	prompt:SetAttribute("ZoneId", zone.id)
	prompt:SetAttribute("ZoneAction", zone.action)
	prompt.Parent = zonePart
	return prompt
end

function HubWorldBuilder.buildLeaderboardBoard(parent, zone, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = createPart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(HubConfig.LEADERBOARD_BOARD.size.X, HubConfig.LEADERBOARD_BOARD.size.Y, 0.4),
		cframe = CFrame.new(zone.position + HubConfig.LEADERBOARD_BOARD.offset)
			* CFrame.Angles(0, math.rad(-90), 0),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Neon,
		canCollide = false,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.TextSize = 28
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, -16, 1, -60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
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

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_MODEL_NAME
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_SIZE.Y * 0.5
	createPart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(35, 40, 52),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallY, -halfZ - wallT * 0.5) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallY, halfZ + wallT * 0.5) },
		{ name = "WallWest", size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX - wallT * 0.5, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX + wallT * 0.5, wallY, 0) },
	}
	for _, wall in walls do
		createPart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(28, 32, 42),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(0, floorY + 0.5, 12)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zoneParts = {}
	for _, zone in HubConfig.ZONES do
		local zoneY = floorY + zone.size.Y * 0.5
		local zonePart = createPart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position.X, zoneY, zone.position.Z),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		zonePart.Transparency = 0.82
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		createZoneLabel(zonePart, zone)
		createProximityPrompt(zonePart, zone)
		zoneParts[zone.id] = zonePart
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 60
	lighting.Parent = spawn

	return hub, zoneParts
end

return HubWorldBuilder
