local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.CanQuery = true
	part.CanTouch = props.canTouch == true
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position)
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	if props.zoneId then
		part:SetAttribute("HubZoneId", props.zoneId)
	end
	return part
end

local function addSign(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, offsetY or 7, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function buildWalls(parent, floorSize, floorPos, height)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = floorPos.Y + height / 2
	local t = HubConfig.WALL_THICKNESS
	local wallColor = Color3.fromRGB(45, 50, 68)

	local specs = {
		{ Vector3.new(floorSize.X + t * 2, height, t), Vector3.new(floorPos.X, y, floorPos.Z + halfZ + t / 2) },
		{ Vector3.new(floorSize.X + t * 2, height, t), Vector3.new(floorPos.X, y, floorPos.Z - halfZ - t / 2) },
		{ Vector3.new(t, height, floorSize.Z), Vector3.new(floorPos.X + halfX + t / 2, y, floorPos.Z) },
		{ Vector3.new(t, height, floorSize.Z), Vector3.new(floorPos.X - halfX - t / 2, y, floorPos.Z) },
	}

	for i, spec in specs do
		makePart({
			name = "Wall" .. i,
			parent = parent,
			size = spec[1],
			position = spec[2],
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end
end

local function buildZone(parent, zone)
	local platform = makePart({
		name = zone.id,
		parent = parent,
		size = zone.size,
		position = zone.position,
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.55,
		canTouch = true,
		zoneId = zone.id,
	})
	addSign(platform, zone.name, zone.size.Y / 2 + 2)
	return platform
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = cfg.size,
		cframe = cfg.cframe,
		color = Color3.fromRGB(25, 28, 40),
		material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "🏆 Nova Liga — Top 5"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 52)
	list.Size = UDim2.new(1, -24, 1, -60)
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

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(35, 38, 52),
		material = Enum.Material.Slate,
	})

	local spawn = makePart({
		name = "Spawn",
		parent = hub,
		size = Vector3.new(6, 0.4, 6),
		cframe = HubConfig.SPAWN_CFRAME * CFrame.new(0, -3.3, 0),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
	})
	addSign(spawn, "Nova Hub", 3)

	buildWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.FLOOR_POSITION, HubConfig.WALL_HEIGHT)

	local zoneParts = {}
	for _, zone in HubConfig.ZONES do
		zoneParts[zone.id] = buildZone(zonesFolder, zone)
	end

	return hub, zoneParts
end

return HubWorldBuilder
