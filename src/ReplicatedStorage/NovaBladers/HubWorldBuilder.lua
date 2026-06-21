local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		name = "Sign",
		parent = parent,
		size = Vector3.new(10, 4, 0.4),
		position = position + Vector3.new(0, 7, 0),
		color = color,
		material = Enum.Material.Neon,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return sign
end

function HubWorldBuilder.buildLeaderboardBoard(parent, position, entries)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(14, 10, 0.6),
		position = position + Vector3.new(0, 6, -6),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Metal,
	})
	board.Orientation = Vector3.new(0, 180, 0)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Nova Liga — Top 5"
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local lines = {}
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	end

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 1, -70)
	body.Position = UDim2.new(0, 10, 0, 65)
	body.BackgroundTransparency = 1
	body.Text = table.concat(lines, "\n")
	body.TextColor3 = Color3.fromRGB(230, 230, 240)
	body.TextScaled = false
	body.TextSize = 28
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Font = Enum.Font.Gotham
	body.Parent = frame

	return board
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = 0
	local half = HubConfig.FLOOR_SIZE / 2

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
	})

	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2
	local wallColor = Color3.fromRGB(28, 30, 38)

	local walls = {
		{ Vector3.new(0, wallY, -half.Z), Vector3.new(half.X * 2 + t, wallH, t) },
		{ Vector3.new(0, wallY, half.Z), Vector3.new(half.X * 2 + t, wallH, t) },
		{ Vector3.new(-half.X, wallY, 0), Vector3.new(t, wallH, half.Z * 2) },
		{ Vector3.new(half.X, wallY, 0), Vector3.new(t, wallH, half.Z * 2) },
	}
	for i, spec in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = spec[2],
			position = spec[1],
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		parent = hub,
		size = Vector3.new(6, 0.2, 6),
		position = HubConfig.SPAWN_OFFSET + Vector3.new(0, floorY + 0.1, 0),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	spawn.Transparency = 0.4

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zoneId,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		zonePart.Transparency = 0.55
		zonePart:SetAttribute("ZoneId", zoneId)
		zonePart:SetAttribute("Action", zone.action)

		addSign(zonesFolder, zone.name, zone.position, zone.color)

		if zoneId == "HallOfFame" then
			HubWorldBuilder.buildLeaderboardBoard(zonesFolder, zone.position, leaderboardEntries or {})
		end
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 80
	light.Parent = spawn

	return hub
end

return HubWorldBuilder
