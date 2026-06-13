local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(40, 40, 40)
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(0, 0, 0)
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonRing(parent, position, radius, color)
	local ring = makePart({
		Name = "NeonRing",
		Size = Vector3.new(radius * 2, 0.35, radius * 2),
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return ring
end

local function addPillar(parent, position, height)
	local pillar = makePart({
		Name = "Pillar",
		Size = Vector3.new(2.5, height, 2.5),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		Color = HubConfig.COLORS.Pillar,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	addNeonRing(parent, position + Vector3.new(0, height + 0.2, 0), 1.8, HubConfig.COLORS.Neon)
	return pillar
end

local function addBillboard(parent, name, position, size, title)
	local board = makePart({
		Name = name,
		Size = Vector3.new(size.X, size.Y, 0.4),
		CFrame = CFrame.new(position),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 300)
	gui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = HubConfig.COLORS.Neon
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromScale(0, 0.22)
	body.Size = UDim2.fromScale(1, 0.78)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(230, 235, 245)
	body.TextScaled = false
	body.TextSize = 22
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = ""
	body.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "HubFloor",
		Size = Vector3.new(HubConfig.HUB_RADIUS * 2, HubConfig.FLOOR_THICKNESS, HubConfig.HUB_RADIUS * 2),
		CFrame = CFrame.new(0, -HubConfig.FLOOR_THICKNESS / 2, 0),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	addNeonRing(hub, Vector3.new(0, 0.15, 0), HubConfig.HUB_RADIUS - 2, HubConfig.COLORS.FloorAccent)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.HUB_SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = hub

	local gatePos = HubConfig.ARENA_ENTRY_OFFSET
	local gateBase = makePart({
		Name = "GateBase",
		Size = Vector3.new(14, 1, 6),
		CFrame = CFrame.new(gatePos + Vector3.new(0, 0.5, 0)),
		Color = HubConfig.COLORS.FloorAccent,
		Parent = gateFolder,
	})

	local portal = makePart({
		Name = "Portal",
		Size = Vector3.new(10, 12, 1),
		CFrame = CFrame.new(gatePos + Vector3.new(0, 7, 0)),
		Color = HubConfig.COLORS.Portal,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = gateFolder,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = HubConfig.GATE_PROMPT_ACTION
	prompt.ObjectText = "Arena-Portal"
	prompt.MaxActivationDistance = HubConfig.GATE_PROMPT_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal

	local sign = makePart({
		Name = "GateSign",
		Size = Vector3.new(8, 2, 0.4),
		CFrame = CFrame.new(gatePos + Vector3.new(0, 14, 0)),
		Color = HubConfig.COLORS.Pillar,
		Parent = gateFolder,
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(320, 80)
	signGui.Parent = sign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBold
	signText.TextColor3 = HubConfig.COLORS.Neon
	signText.TextScaled = true
	signText.Text = "ARENA"
	signText.Parent = signGui

	local pillarOffsets = {
		Vector3.new(-24, 0, 18),
		Vector3.new(24, 0, 18),
		Vector3.new(-30, 0, -8),
		Vector3.new(30, 0, -8),
	}
	for i, offset in pillarOffsets do
		addPillar(hub, offset, 10 + (i % 2))
	end

	addBillboard(hub, "StatsBoard", Vector3.new(-22, 7, 2), Vector3.new(10, 7, 0.4), "Deine Stats")
	addBillboard(hub, "LeaderboardBoard", Vector3.new(22, 7, 2), Vector3.new(10, 7, 0.4), "Top Spieler")
	addBillboard(hub, "ModeBoard", Vector3.new(0, 9, 24), Vector3.new(12, 4, 0.4), "Spielmodus")

	local welcome = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(16, 3, 0.4),
		CFrame = CFrame.new(0, 8, HubConfig.HUB_SPAWN.Z + 8),
		Color = HubConfig.COLORS.Pillar,
		Parent = hub,
	})
	local welcomeGui = Instance.new("SurfaceGui")
	welcomeGui.Face = Enum.NormalId.Front
	welcomeGui.CanvasSize = Vector2.new(480, 90)
	welcomeGui.Parent = welcome
	local welcomeText = Instance.new("TextLabel")
	welcomeText.Size = UDim2.fromScale(1, 1)
	welcomeText.BackgroundTransparency = 1
	welcomeText.Font = Enum.Font.GothamBold
	welcomeText.TextColor3 = HubConfig.COLORS.Neon
	welcomeText.TextScaled = true
	welcomeText.Text = "NOVA BLADERS — Zum Portal laufen"
	welcomeText.Parent = welcomeGui

	return hub, spawn, portal
end

return HubWorldBuilder
