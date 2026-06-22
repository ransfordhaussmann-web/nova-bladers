local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(40, 44, 56)
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position)
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = zone.label
	title.Parent = billboard

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(200, 200, 210)
	hint.TextScaled = true
	hint.Text = zone.hint
	hint.Parent = billboard
end

local function addProximityPrompt(part, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floor = makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_CENTER,
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Slate,
		parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.FLOOR_CENTER.Y + HubConfig.WALL_HEIGHT / 2
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ name = "WallNorth", pos = Vector3.new(0, wallY, HubConfig.FLOOR_CENTER.Z - halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, HubConfig.WALL_HEIGHT, wallT) },
		{ name = "WallSouth", pos = Vector3.new(0, wallY, HubConfig.FLOOR_CENTER.Z + halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, HubConfig.WALL_HEIGHT, wallT) },
		{ name = "WallWest", pos = Vector3.new(-halfX, wallY, HubConfig.FLOOR_CENTER.Z), size = Vector3.new(wallT, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallEast", pos = Vector3.new(halfX, wallY, HubConfig.FLOOR_CENTER.Z), size = Vector3.new(wallT, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(24, 28, 38),
			material = Enum.Material.Concrete,
			parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			name = zone.id,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
			parent = zonesFolder,
		})
		pad.Transparency = 0.35
		pad:SetAttribute("ZoneId", zone.id)
		addZoneLabel(pad, zone)
		addProximityPrompt(pad, zone.hint)
	end

	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		size = boardCfg.size,
		position = boardCfg.position,
		color = Color3.fromRGB(18, 20, 28),
		material = Enum.Material.Metal,
		parent = hub,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardGui"
	surface.Face = boardCfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "BoardLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.TextSize = 28
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "🏆 Ruhmeshalle\nLade Rangliste..."
	label.Parent = surface

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	hub.PrimaryPart = floor
	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
