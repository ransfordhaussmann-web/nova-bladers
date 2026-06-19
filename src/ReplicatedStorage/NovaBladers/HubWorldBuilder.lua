local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Name = props.Name or "Part"
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.CanCollide = props.CanCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, parent.Size.Y * 0.5 + 4, 0)
	attach.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 72)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = attach

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 0, 28)
	titleLabel.Position = UDim2.fromOffset(6, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -12, 0, 32)
	subLabel.Position = UDim2.fromOffset(6, 34)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(210, 215, 230)
	subLabel.TextWrapped = true
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextYAlignment = Enum.TextYAlignment.Top
	subLabel.Text = subtitle
	subLabel.Parent = frame
end

local function addProximityPrompt(parent, zoneDef)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = HubConfig.PROXIMITY.ActionText
	prompt.ObjectText = zoneDef.label
	prompt.MaxActivationDistance = HubConfig.PROXIMITY.MaxActivationDistance
	prompt.HoldDuration = HubConfig.PROXIMITY.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Name = "ZonePrompt"
	prompt:SetAttribute("ZoneId", zoneDef.id)
	if zoneDef.remote then
		prompt:SetAttribute("RemoteName", zoneDef.remote)
	end
	prompt.Parent = parent
	return prompt
end

local function buildLeaderboardBoard(parent, origin, zoneDef)
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Size = Vector3.new(12, 8, 0.6),
		Color = Color3.fromRGB(28, 30, 40),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(origin + Vector3.new(0, 5, zoneDef.size.Z * 0.5 + 1))
			* CFrame.Angles(0, math.pi, 0),
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = zoneDef.color
	title.Text = "🏆 Nova Liga"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 48)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 16
	list.TextColor3 = Color3.fromRGB(220, 225, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Text = "Lade Rangliste..."
	list.Parent = frame

	board:SetAttribute("ZoneId", zoneDef.id)
	return board
end

local function buildZone(parent, origin, zoneDef)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneDef.id .. "Zone"
	zoneFolder.Parent = parent

	local pad = makePart({
		Name = "Pad",
		Parent = zoneFolder,
		Size = zoneDef.size,
		Color = zoneDef.color,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(origin + Vector3.new(0, zoneDef.size.Y * 0.5, 0)),
	})
	pad.Transparency = 0.25

	makePart({
		Name = "Rim",
		Parent = zoneFolder,
		Size = zoneDef.size + Vector3.new(2, 0.4, 2),
		Color = Color3.fromRGB(60, 64, 78),
		Material = Enum.Material.Concrete,
		CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)),
	})

	addBillboard(pad, zoneDef.label, zoneDef.hint, zoneDef.color)

	if zoneDef.id ~= "Leaderboard" then
		addProximityPrompt(pad, zoneDef)
	else
		buildLeaderboardBoard(zoneFolder, origin, zoneDef)
	end

	pad:SetAttribute("ZoneId", zoneDef.id)
	return zoneFolder, pad
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.HUB_ORIGIN

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		Color = Color3.fromRGB(38, 42, 52),
		Material = Enum.Material.Slate,
		CFrame = CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0)),
	})

	local accent = makePart({
		Name = "CenterRing",
		Parent = hub,
		Size = Vector3.new(20, 0.4, 20),
		Color = Color3.fromRGB(90, 120, 255),
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(origin + Vector3.new(0, 0.3, 0)),
		CanCollide = false,
	})
	accent.Transparency = 0.35

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5

	for _, spec in {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	} do
		makePart({
			Name = spec.name,
			Parent = hub,
			Size = spec.size,
			Color = Color3.fromRGB(55, 58, 70),
			Material = Enum.Material.Brick,
			CFrame = CFrame.new(origin + spec.pos),
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneKey in HubConfig.ZONE_ORDER do
		local zoneDef = HubConfig.ZONES[zoneKey]
		local zoneOrigin = origin + zoneDef.offset
		buildZone(zonesFolder, zoneOrigin, zoneDef)
	end

	local welcome = makePart({
		Name = "WelcomeSign",
		Parent = hub,
		Size = Vector3.new(1, 1, 1),
		CanCollide = false,
		Transparency = 1,
		CFrame = CFrame.new(origin + Vector3.new(0, 3, 12)),
	})
	addBillboard(welcome, "Nova Hub", "Laufe zu Arena, Bey-Labor oder Ruhmeshalle.", Color3.fromRGB(140, 180, 255))

	hub:SetAttribute("Built", true)
	hub:SetAttribute("Origin", origin)
	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild("NovaHub")
	local origin = hub and hub:GetAttribute("Origin")
	if typeof(origin) ~= "Vector3" then
		origin = HubConfig.HUB_ORIGIN
	end
	return CFrame.new(origin + HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.findLeaderboardBoard()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end
	local zone = zones:FindFirstChild("LeaderboardZone")
	if not zone then return nil end
	return zone:FindFirstChild("LeaderboardBoard")
end

return HubWorldBuilder
