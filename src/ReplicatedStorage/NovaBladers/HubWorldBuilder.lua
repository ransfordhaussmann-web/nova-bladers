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

local function createWalls(parent, floorSize, wallHeight, thickness)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallColor = Color3.fromRGB(50, 55, 75)

	local walls = {
		{ Vector3.new(0, wallHeight / 2 + 0.5, halfZ + thickness / 2), Vector3.new(floorSize.X + thickness * 2, wallHeight, thickness) },
		{ Vector3.new(0, wallHeight / 2 + 0.5, -halfZ - thickness / 2), Vector3.new(floorSize.X + thickness * 2, wallHeight, thickness) },
		{ Vector3.new(halfX + thickness / 2, wallHeight / 2 + 0.5, 0), Vector3.new(thickness, wallHeight, floorSize.Z) },
		{ Vector3.new(-halfX - thickness / 2, wallHeight / 2 + 0.5, 0), Vector3.new(thickness, wallHeight, floorSize.Z) },
	}

	for index, wall in walls do
		local part = makePart({
			Name = "Wall" .. index,
			Size = wall[2],
			Position = wall[1],
			Color = wallColor,
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		part:SetAttribute("HubPart", true)
	end
end

local function createZoneMarker(parent, zone)
	local marker = makePart({
		Name = "Zone_" .. zone.id,
		Size = zone.size,
		Position = zone.position,
		Color = zone.color,
		Transparency = 0.35,
		CanCollide = false,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	marker:SetAttribute("ZoneId", zone.id)
	marker:SetAttribute("ZoneAction", zone.action)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.hint
	prompt.ObjectText = zone.name
	prompt.KeyboardKeyCode = zone.promptKey
	prompt.MaxActivationDistance = math.max(zone.size.X, zone.size.Z) * 0.6 + 4
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker

	local label = makePart({
		Name = "Label",
		Size = Vector3.new(zone.size.X * 0.8, 1.5, 0.2),
		Position = zone.position + Vector3.new(0, zone.size.Y / 2 + 2, 0),
		Color = zone.color,
		CanCollide = false,
		Material = Enum.Material.SmoothPlastic,
		Parent = marker,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneBillboard"
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = label

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Text = zone.name
	text.Parent = billboard

	return marker
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			Name = "LeaderboardBoard",
			Size = cfg.size,
			Position = cfg.position,
			Color = Color3.fromRGB(25, 28, 38),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end

	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Name = "LeaderboardSurface"
		surface.Face = cfg.face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 40
		surface.Parent = board
	end

	local frame = surface:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		frame.BorderSizePixel = 0
		frame.Parent = surface

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 48)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.fromRGB(255, 210, 80)
		title.TextScaled = true
		title.Text = "🏆 Ruhmeshalle"
		title.Parent = frame

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.fromOffset(12, 52)
		list.Size = UDim2.new(1, -24, 1, -60)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextSize = 22
		list.TextWrapped = true
		list.Parent = frame
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	frame.List.Text = table.concat(lines, "\n")

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

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0.5, 0),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
		Parent = hub,
	})
	floor:SetAttribute("HubPart", true)

	createWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS)

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 0.5, 6),
		Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = hub,
	})
	spawn:SetAttribute("HubSpawn", true)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZoneMarker(zonesFolder, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
