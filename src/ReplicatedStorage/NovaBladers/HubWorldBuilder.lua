local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addZoneLabel(part, title, subtitle)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	titleLabel.Position = UDim2.fromScale(0, 0.1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.3, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = frame
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(10, 6, 0.5),
		cframe = CFrame.new(26, 5, 2) * CFrame.Angles(0, math.rad(180), 0),
		color = Color3.fromRGB(30, 28, 22),
		material = Enum.Material.Wood,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 22, 18)
	label.BackgroundTransparency = 0.1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.TextScaled = false
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Parent = gui

	local lines = {"🏆 Ruhmeshalle — Top 5"}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")

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

	local floorY = 0
	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, -15),
		color = Color3.fromRGB(55, 58, 68),
		material = Enum.Material.Slate,
	})

	local halfW = HubConfig.FLOOR_SIZE.X / 2
	local halfD = HubConfig.FLOOR_SIZE.Z / 2
	local centerZ = -15
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, floorY + wallH / 2, centerZ - halfD - wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, floorY + wallH / 2, centerZ + halfD + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(-halfW - wallT / 2, floorY + wallH / 2, centerZ), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfW + wallT / 2, floorY + wallH / 2, centerZ), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(40, 42, 52),
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
			cframe = CFrame.new(zone.position),
			color = zone.color,
			transparency = 0.35,
			canCollide = false,
		})
		marker:SetAttribute("ZoneId", zone.id)
		addZoneLabel(marker, zone.name, zone.hint)

		local light = Instance.new("PointLight")
		light.Color = zone.color
		light.Brightness = 0.6
		light.Range = 14
		light.Parent = marker
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
