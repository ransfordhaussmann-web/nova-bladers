local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or HubConfig.THEME.Floor
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	return part
end

local function addGlow(parent, position, color, size)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = size or 14
	light.Parent = parent

	local glow = makePart({
		Name = "Glow",
		Parent = parent,
		Size = Vector3.new(0.4, 0.4, 0.4),
		Position = position,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	glow.Shape = Enum.PartType.Ball
	return glow
end

local function addProximityPrompt(parent, zoneKey)
	local zone = HubConfig.ZONES[zoneKey]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = zoneKey .. "Prompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = HubConfig.PROXIMITY.MaxActivationDistance
	prompt.HoldDuration = HubConfig.PROXIMITY.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function addBillboard(parent, size, title)
	local gui = Instance.new("SurfaceGui")
	gui.Name = title .. "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = HubConfig.THEME.Accent
	stroke.Thickness = 2
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(1, -16, 0, 32)
	label.Position = UDim2.fromOffset(8, 8)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = HubConfig.THEME.Glow
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = title
	label.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -48)
	body.Position = UDim2.fromOffset(8, 40)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 14
	body.TextColor3 = Color3.fromRGB(220, 230, 255)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "…"
	body.Parent = frame

	return gui, body
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = HubConfig.THEME.Floor,
		Material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	makePart({
		Name = "CenterRing",
		Parent = hub,
		Size = Vector3.new(14, 0.3, 14),
		Position = Vector3.new(0, 0.65, 0),
		Color = HubConfig.THEME.Accent,
		Material = Enum.Material.Neon,
	}).Shape = Enum.PartType.Cylinder

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallThick = 1
	local wallColor = HubConfig.THEME.Trim

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(halfX * 2, wallH, wallThick) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(halfX * 2, wallH, wallThick) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallThick, wallH, halfZ * 2) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallThick, wallH, halfZ * 2) },
	}
	for i, spec in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Position = spec[1],
			Size = spec[2],
			Color = wallColor,
			Material = Enum.Material.Concrete,
		})
	end

	local portalZone = HubConfig.ZONES.ArenaPortal
	local portalBase = makePart({
		Name = "ArenaPortal",
		Parent = hub,
		Size = Vector3.new(10, 8, 2),
		Position = portalZone.position + Vector3.new(0, 3, 0),
		Color = HubConfig.THEME.Trim,
		Material = Enum.Material.Metal,
	})
	addGlow(portalBase, portalBase.Position + Vector3.new(0, 2, -1), HubConfig.THEME.Accent, 18)
	addProximityPrompt(portalBase, "ArenaPortal")

	local portalSign = makePart({
		Name = "PortalSign",
		Parent = hub,
		Size = Vector3.new(8, 2, 0.4),
		Position = portalZone.position + Vector3.new(0, 7.5, 1.2),
		Color = HubConfig.THEME.Accent,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = portalSign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextSize = 28
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.Text = "ARENA"
	signLabel.Parent = signGui

	local beyZone = HubConfig.ZONES.BeySelect
	local beyPedestal = makePart({
		Name = "BeySelectPedestal",
		Parent = hub,
		Size = Vector3.new(5, 4, 5),
		Position = beyZone.position + Vector3.new(0, 1.5, 0),
		Color = HubConfig.THEME.Trim,
		Material = Enum.Material.Marble,
	})
	addGlow(beyPedestal, beyPedestal.Position + Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 200, 80), 12)
	addProximityPrompt(beyPedestal, "BeySelect")

	local lbZone = HubConfig.ZONES.Leaderboard
	local lbBoard = makePart({
		Name = "LeaderboardBoard",
		Parent = hub,
		Size = Vector3.new(0.4, 6, 8),
		Position = lbZone.position + Vector3.new(0, 3, 0),
		Color = HubConfig.THEME.Trim,
		Material = Enum.Material.Wood,
	})
	addBillboard(lbBoard, lbZone.boardSize, "🏆 Top Spieler")

	local statsZone = HubConfig.ZONES.Stats
	local statsBoard = makePart({
		Name = "StatsBoard",
		Parent = hub,
		Size = Vector3.new(8, 4, 0.4),
		Position = statsZone.position + Vector3.new(0, 2.5, 0),
		Color = HubConfig.THEME.Trim,
		Material = Enum.Material.Wood,
	})
	addBillboard(statsBoard, statsZone.boardSize, "Deine Stats")

	local pillarOffsets = {
		Vector3.new(-28, 0, -28),
		Vector3.new(28, 0, -28),
		Vector3.new(-28, 0, 28),
		Vector3.new(28, 0, 28),
	}
	for i, offset in pillarOffsets do
		local pillar = makePart({
			Name = "Pillar" .. i,
			Parent = hub,
			Size = Vector3.new(2, 10, 2),
			Position = offset + Vector3.new(0, 5, 0),
			Color = HubConfig.THEME.Trim,
			Material = Enum.Material.Metal,
		})
		addGlow(pillar, pillar.Position + Vector3.new(0, 5.5, 0), HubConfig.THEME.Glow, 10)
	end

	hub:SetAttribute("Built", true)
	return hub
end

return HubWorldBuilder
