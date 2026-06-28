local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addNeonTrim(parent, position, size, color)
	local trim = makePart({
		name = "Trim",
		parent = parent,
		position = position,
		size = size,
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	trim.Transparency = 0.15
	return trim
end

local function addBillboard(parent, size, offset, text, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Parent = frame

	if textSize then
		label.TextScaled = false
		label.TextSize = textSize
	end

	return gui, label
end

local function addProximityPrompt(parent, actionText, objectText, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = distance or HubConfig.PORTAL_PROMPT_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local theme = HubConfig.THEME
	local floorY = HubConfig.SPAWN_POSITION.Y - 2.5

	local floor = makePart({
		name = "Floor",
		parent = hub,
		position = Vector3.new(0, floorY, 0),
		size = HubConfig.FLOOR_SIZE,
		color = theme.FloorColor,
		material = Enum.Material.Slate,
	})

	addNeonTrim(hub, floor.Position + Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 0.05, 0), Vector3.new(HubConfig.FLOOR_SIZE.X, 0.15, HubConfig.FLOOR_SIZE.Z), theme.AccentColor)

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	for _, wallDef in {
		{ pos = Vector3.new(0, wallY, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ pos = Vector3.new(0, wallY, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ pos = Vector3.new(-halfX, wallY, 0), size = Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ pos = Vector3.new(halfX, wallY, 0), size = Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
	} do
		makePart({
			name = "Wall",
			parent = hub,
			position = wallDef.pos,
			size = wallDef.size,
			color = theme.WallColor,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	local portalCfg = HubConfig.ARENA_PORTAL
	local portal = makePart({
		name = "ArenaPortal",
		parent = zones,
		position = portalCfg.position,
		size = portalCfg.size,
		color = theme.PortalColor,
		material = Enum.Material.Neon,
	})
	portal.Transparency = 0.35
	portal.CanCollide = false
	portal:SetAttribute("ZoneId", "ArenaPortal")
	addBillboard(portal, nil, Vector3.new(0, 0, -portalCfg.size.Z / 2 - 0.1), "ARENA\nBetreten", 28)
	addProximityPrompt(portal, "Betreten", "Spin-Arena", HubConfig.PORTAL_PROMPT_DISTANCE)

	local portalPad = makePart({
		name = "PortalPad",
		parent = zones,
		position = portalCfg.position - Vector3.new(0, portalCfg.size.Y / 2 + 0.5, 4),
		size = Vector3.new(10, 0.3, 10),
		color = theme.TrimColor,
		material = Enum.Material.Metal,
	})
	portalPad.CanCollide = false

	local statsCfg = HubConfig.STATS_TERMINAL
	local statsTerminal = makePart({
		name = "StatsTerminal",
		parent = zones,
		position = statsCfg.position,
		size = statsCfg.size,
		color = theme.TrimColor,
		material = Enum.Material.Metal,
	})
	statsTerminal:SetAttribute("ZoneId", "StatsTerminal")
	local _, statsLabel = addBillboard(statsTerminal, nil, Vector3.new(0, 0, -statsCfg.size.Z / 2 - 0.05), "Deine Stats\nLaden...", 22)
	statsLabel.Name = "StatsLabel"

	local boardCfg = HubConfig.LEADERBOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = zones,
		position = boardCfg.position,
		size = boardCfg.size,
		color = theme.WallColor,
		material = Enum.Material.SmoothPlastic,
	})
	board:SetAttribute("ZoneId", "Leaderboard")
	local _, boardLabel = addBillboard(board, nil, Vector3.new(0, 0, -boardCfg.size.Z / 2 - 0.05), "Top Spieler\nLaden...", 20)
	boardLabel.Name = "LeaderboardLabel"

	local showcase = Instance.new("Folder")
	showcase.Name = "BeyShowcase"
	showcase.Parent = hub

	local showcaseCenter = HubConfig.BEY_SHOWCASE.position
	makePart({
		name = "ShowcasePlatform",
		parent = showcase,
		position = showcaseCenter - Vector3.new(0, 0.5, 0),
		size = Vector3.new(16, 1, 16),
		color = theme.TrimColor,
		material = Enum.Material.Marble,
	})

	local angleStep = (2 * math.pi) / #BeyCatalog
	for i, bey in BeyCatalog do
		local angle = (i - 1) * angleStep
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * HubConfig.BEY_SHOWCASE.radius
		local pedestal = makePart({
			name = bey.id .. "Pedestal",
			parent = showcase,
			position = showcaseCenter + offset + Vector3.new(0, 1, 0),
			size = Vector3.new(2.5, 2, 2.5),
			color = bey.color,
			material = Enum.Material.Neon,
		})
		pedestal.Transparency = 0.4

		local display = makePart({
			name = bey.id .. "Display",
			parent = showcase,
			position = pedestal.Position + Vector3.new(0, 2.2, 0),
			size = Vector3.new(2, 0.8, 2),
			color = bey.color,
			material = Enum.Material.Neon,
		})
		display.CanCollide = false
		addBillboard(display, nil, Vector3.new(0, 0, -0.6), bey.name, 18)
	end

	local titleSign = makePart({
		name = "TitleSign",
		parent = hub,
		position = Vector3.new(0, 12, 0),
		size = Vector3.new(20, 3, 1),
		color = theme.AccentColor,
		material = Enum.Material.Neon,
	})
	titleSign.CanCollide = false
	titleSign.Transparency = 0.5
	addBillboard(titleSign, nil, Vector3.new(0, 0, -0.6), "NOVA BLADERS", 36)

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 40
	light.Color = theme.AccentColor
	light.Parent = floor

	return hub
end

function HubWorldBuilder.getZone(hub, zoneId)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end
	for _, child in zones:GetChildren() do
		if child:GetAttribute("ZoneId") == zoneId then
			return child
		end
	end
	return nil
end

return HubWorldBuilder
