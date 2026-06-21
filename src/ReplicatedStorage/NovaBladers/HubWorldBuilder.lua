local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Name = props.name or "Part"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 72)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(8, 6)
	titleLabel.Size = UDim2.new(1, -16, 0, 28)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = 20
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(8, 34)
	subtitleLabel.Size = UDim2.new(1, -16, 0, 24)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(190, 195, 210)
	subtitleLabel.TextSize = 14
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = frame
end

local function buildWalls(folder, origin, floorSize, wallConfig)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local height = wallConfig.height
	local thickness = wallConfig.thickness
	local y = origin.Y + height / 2

	local walls = {
		{ Vector3.new(0, y, origin.Z - halfZ - thickness / 2), Vector3.new(floorSize.X + thickness * 2, height, thickness) },
		{ Vector3.new(0, y, origin.Z + halfZ + thickness / 2), Vector3.new(floorSize.X + thickness * 2, height, thickness) },
		{ Vector3.new(origin.X - halfX - thickness / 2, y, 0), Vector3.new(thickness, height, floorSize.Z) },
		{ Vector3.new(origin.X + halfX + thickness / 2, y, 0), Vector3.new(thickness, height, floorSize.Z) },
	}

	for index, wall in walls do
		makePart({
			name = "Wall" .. index,
			parent = folder,
			size = wall[2],
			cframe = CFrame.new(origin + wall[1]),
			color = wallConfig.color,
			material = wallConfig.material,
		})
	end
end

local function buildZone(folder, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneConfig.id
	zoneFolder.Parent = folder

	local platform = makePart({
		name = "Platform",
		parent = zoneFolder,
		size = Vector3.new(zoneConfig.size.X, 1, zoneConfig.size.Z),
		cframe = CFrame.new(HubConfig.ORIGIN + zoneConfig.position + Vector3.new(0, 0.5, 0)),
		color = zoneConfig.color,
		material = Enum.Material.Neon,
	})

	local marker = makePart({
		name = "Marker",
		parent = zoneFolder,
		size = Vector3.new(zoneConfig.size.X * 0.6, zoneConfig.size.Y, zoneConfig.size.X * 0.6),
		cframe = CFrame.new(HubConfig.ORIGIN + zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2, 0)),
		color = zoneConfig.color,
		material = Enum.Material.Glass,
		transparency = 0.35,
		canCollide = false,
	})

	local promptAnchor = makePart({
		name = "PromptAnchor",
		parent = zoneFolder,
		size = Vector3.new(1, 1, 1),
		cframe = marker.CFrame,
		color = zoneConfig.color,
		transparency = 1,
		canCollide = false,
	})

	promptAnchor:SetAttribute("ZoneId", zoneConfig.id)
	promptAnchor:SetAttribute("ZoneAction", zoneConfig.action)
	promptAnchor:SetAttribute("ZoneLabel", zoneConfig.label)
	promptAnchor:SetAttribute("ZoneHint", zoneConfig.hint)

	addBillboard(promptAnchor, zoneConfig.label, zoneConfig.hint, zoneConfig.color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.label
	prompt.ObjectText = zoneConfig.hint
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HubConfig.PROXIMITY_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	return zoneFolder, platform, promptAnchor
end

function HubWorldBuilder.buildLeaderboardBoard(parent, lines)
	local boardConfig = HubConfig.LEADERBOARD_BOARD
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			name = "LeaderboardBoard",
			parent = parent,
			size = boardConfig.size,
			cframe = CFrame.new(HubConfig.ORIGIN + boardConfig.position),
			color = Color3.fromRGB(24, 26, 36),
			material = Enum.Material.Metal,
		})

		local surface = Instance.new("SurfaceGui")
		surface.Name = "BoardGui"
		surface.Face = boardConfig.face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 50
		surface.Parent = board

		local frame = Instance.new("Frame")
		frame.Name = "Content"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
		frame.BorderSizePixel = 0
		frame.Parent = surface

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 48)
		title.Font = Enum.Font.GothamBold
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 220, 90)
		title.TextSize = 28
		title.Parent = frame

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(12, 52)
		body.Size = UDim2.new(1, -24, 1, -64)
		body.Font = Enum.Font.Gotham
		body.Text = ""
		body.TextColor3 = Color3.fromRGB(230, 232, 240)
		body.TextSize = 22
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.Parent = frame
	end

	local body = board.BoardGui.Content:FindFirstChild("Body")
	if body then
		body.Text = table.concat(lines, "\n")
	end

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

	local origin = HubConfig.ORIGIN
	local floorConfig = HubConfig.FLOOR

	makePart({
		name = "Floor",
		parent = hub,
		size = floorConfig.size,
		cframe = CFrame.new(origin + Vector3.new(0, floorConfig.size.Y / 2, 0)),
		color = floorConfig.color,
		material = floorConfig.material,
	})

	buildWalls(hub, origin, floorConfig.size, HubConfig.WALLS)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneConfig in HubConfig.ZONES do
		buildZone(zonesFolder, zoneConfig)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	HubWorldBuilder.buildLeaderboardBoard(hub, { "Lade Rangliste..." })

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = spawn

	return hub
end

return HubWorldBuilder
