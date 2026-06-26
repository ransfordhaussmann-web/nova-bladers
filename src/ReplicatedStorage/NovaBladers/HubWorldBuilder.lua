local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(40, 44, 60)
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonTrim(parent, position, size, color)
	local trim = makePart({
		Name = "Trim",
		Parent = parent,
		Position = position,
		Size = size,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	trim.Transparency = 0.15
	return trim
end

local function createPortal(parent, zoneDef, color)
	local portal = Instance.new("Model")
	portal.Name = zoneDef.id .. "Portal"
	portal.Parent = parent

	local basePos = zoneDef.position
	local pad = makePart({
		Name = "Pad",
		Parent = portal,
		Position = basePos + Vector3.new(0, 0.6, 0),
		Size = Vector3.new(14, 1.2, 14),
		Color = color,
		Material = Enum.Material.Neon,
	})
	pad.Transparency = 0.35

	local ring = makePart({
		Name = "Ring",
		Parent = portal,
		Position = basePos + Vector3.new(0, 0.2, 0),
		Size = Vector3.new(16, 0.4, 16),
		Color = HubConfig.COLORS.Trim,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	ring.Transparency = 0.5

	for i = 1, 2 do
		local pillar = makePart({
			Name = "Pillar" .. i,
			Parent = portal,
			Position = basePos + Vector3.new((i == 1 and -6 or 6), 5, -4),
			Size = Vector3.new(1.2, 10, 1.2),
			Color = HubConfig.COLORS.FloorAccent,
			Material = Enum.Material.Metal,
		})
		addNeonTrim(portal, pillar.Position + Vector3.new(0, 5.2, 0), Vector3.new(1.6, 0.3, 1.6), color)
	end

	local arch = makePart({
		Name = "Arch",
		Parent = portal,
		Position = basePos + Vector3.new(0, 8.5, -4),
		Size = Vector3.new(14, 1.2, 1.2),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
	})

	local sign = makePart({
		Name = "Sign",
		Parent = portal,
		Position = basePos + Vector3.new(0, 10.5, -4.2),
		Size = Vector3.new(12, 3, 0.4),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = color
	title.TextScaled = true
	title.Text = zoneDef.label
	title.Parent = signGui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromScale(0, 0.55)
	subtitle.Size = UDim2.fromScale(1, 0.45)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextColor3 = Color3.fromRGB(200, 210, 230)
	subtitle.TextScaled = true
	subtitle.Text = zoneDef.description
	subtitle.Parent = signGui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = HubConfig.PROMPT.ActionText
	prompt.ObjectText = zoneDef.prompt
	prompt.HoldDuration = HubConfig.PROMPT.HoldDuration
	prompt.MaxActivationDistance = HubConfig.PROMPT.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	portal:SetAttribute("ZoneId", zoneDef.id)
	portal.PrimaryPart = pad
	return portal
end

local function createBoard(parent, boardDef)
	local board = makePart({
		Name = boardDef.title:gsub("%s+", "") .. "Board",
		Parent = parent,
		Position = boardDef.position,
		Size = Vector3.new(0.6, 10, 16),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = boardDef.face
	gui.CanvasSize = Vector2.new(400, 500)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundColor3 = HubConfig.COLORS.Floor
	title.BackgroundTransparency = 0.2
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = HubConfig.COLORS.Trim
	title.TextSize = 22
	title.Text = boardDef.title
	title.Parent = gui

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0, 52)
	body.Size = UDim2.new(1, -8, 1, -60)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(220, 228, 245)
	body.TextSize = 18
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "Lade…"
	body.Parent = gui

	return board
end

local function createFloor(parent)
	local floor = makePart({
		Name = "Floor",
		Parent = parent,
		Position = Vector3.new(0, -HubConfig.FLOOR_HEIGHT / 2, 0),
		Size = Vector3.new(HubConfig.FLOOR_RADIUS * 2, HubConfig.FLOOR_HEIGHT, HubConfig.FLOOR_RADIUS * 2),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	local centerGlow = makePart({
		Name = "CenterGlow",
		Parent = parent,
		Position = Vector3.new(0, 0.15, HubConfig.SPAWN_OFFSET.Z),
		Size = Vector3.new(24, 0.3, 24),
		Color = HubConfig.COLORS.Trim,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	centerGlow.Transparency = 0.6

	addNeonTrim(parent, Vector3.new(0, 0.25, HubConfig.SPAWN_OFFSET.Z), Vector3.new(26, 0.2, 26), HubConfig.COLORS.Trim)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Neutral = true
	spawn.Parent = parent

	local welcome = makePart({
		Name = "WelcomeSign",
		Parent = parent,
		Position = Vector3.new(0, 9, 14),
		Size = Vector3.new(20, 4, 0.5),
		Color = HubConfig.COLORS.Floor,
		CanCollide = false,
	})

	local welcomeGui = Instance.new("SurfaceGui")
	welcomeGui.Face = Enum.NormalId.Front
	welcomeGui.Parent = welcome

	local welcomeText = Instance.new("TextLabel")
	welcomeText.Size = UDim2.fromScale(1, 1)
	welcomeText.BackgroundTransparency = 1
	welcomeText.Font = Enum.Font.GothamBold
	welcomeText.TextColor3 = HubConfig.COLORS.Trim
	welcomeText.TextScaled = true
	welcomeText.Text = "NOVA BLADERS — HUB"
	welcomeText.Parent = welcomeGui

	return floor, spawn
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	createFloor(hub)

	createPortal(hub, HubConfig.ZONES.Training, HubConfig.COLORS.Training)
	createPortal(hub, HubConfig.ZONES.OneVOne, HubConfig.COLORS.OneVOne)
	createPortal(hub, HubConfig.ZONES.FFA, HubConfig.COLORS.FFA)
	createPortal(hub, HubConfig.ZONES.BeySelect, HubConfig.COLORS.BeySelect)

	createBoard(hub, HubConfig.BOARDS.Leaderboard)
	createBoard(hub, HubConfig.BOARDS.Stats)

	return hub
end

function HubWorldBuilder.getHub()
	return workspace:FindFirstChild(HubConfig.ROOT_NAME)
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

function HubWorldBuilder.getZonePortals()
	local hub = HubWorldBuilder.getHub()
	if not hub then return {} end
	local portals = {}
	for _, child in hub:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ZoneId") then
			portals[child:GetAttribute("ZoneId")] = child
		end
	end
	return portals
end

function HubWorldBuilder.getBoard(boardKey)
	local hub = HubWorldBuilder.getHub()
	if not hub then return nil end
	local boardDef = HubConfig.BOARDS[boardKey]
	if not boardDef then return nil end
	local name = boardDef.title:gsub("%s+", "") .. "Board"
	return hub:FindFirstChild(name)
end

return HubWorldBuilder
