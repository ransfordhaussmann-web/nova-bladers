local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	if props.parent then
		part.Parent = props.parent
	end
	return part
end

local function makeZoneMarker(parent, zone)
	local colors = HubConfig.COLORS
	local color = colors[zone.colorKey] or colors.Accent

	local pad = makePart({
		name = "Zone_" .. zone.id,
		parent = parent,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = color,
		transparency = 0.55,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("ZoneAction", zone.action or "")

	local sign = makePart({
		name = "Sign_" .. zone.id,
		parent = parent,
		size = Vector3.new(zone.size.X * 0.9, 3, 0.4),
		cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2, 0)),
		color = colors.Wall,
		material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = zone.name
	label.Parent = gui

	return pad
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local colors = HubConfig.COLORS

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = boardCfg.size,
		cframe = CFrame.new(boardCfg.position),
		color = colors.Wall,
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = boardCfg.face
	gui.LightInfluence = 0
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = colors.Hall
	title.TextScaled = true
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.new(0, 8, 0, 52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 22
	list.TextWrapped = true
	list.Parent = frame

	HubWorldBuilder.updateLeaderboardBoard(board, entries)
	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local entriesLabel = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Entries")
	if not entriesLabel then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	entriesLabel.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 2
	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = HubConfig.COLORS.Floor,
		material = Enum.Material.Concrete,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ Vector3.new(0, wallY, halfZ + 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2) },
		{ Vector3.new(0, wallY, -halfZ - 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2) },
		{ Vector3.new(halfX + 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 2) },
		{ Vector3.new(-halfX - 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 2) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = HubConfig.COLORS.Wall,
			material = Enum.Material.Brick,
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		parent = hub,
		size = Vector3.new(6, 0.5, 6),
		cframe = CFrame.new(HubConfig.SPAWN_POSITION - Vector3.new(0, 2.25, 0)),
		color = HubConfig.COLORS.Accent,
		transparency = 0.3,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	spawn:SetAttribute("IsHubSpawn", true)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zonePads = {}
	for _, zone in HubConfig.ZONES do
		zonePads[zone.id] = makeZoneMarker(zonesFolder, zone)
	end

	local centerLight = Instance.new("PointLight")
	centerLight.Brightness = 1.2
	centerLight.Range = 80
	centerLight.Color = HubConfig.COLORS.Accent
	centerLight.Parent = hub.Floor

	return hub, zonePads
end

return HubWorldBuilder
