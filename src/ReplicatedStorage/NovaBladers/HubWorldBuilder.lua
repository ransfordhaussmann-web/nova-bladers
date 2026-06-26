local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(30, 30, 40)
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new()
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonTrim(parent, cframe, size)
	local trim = makePart({
		Name = "NeonTrim",
		Parent = parent,
		Size = size,
		CFrame = cframe,
		Material = Enum.Material.Neon,
		Color = HubConfig.COLORS.Neon,
		CanCollide = false,
	})
	return trim
end

local function addBoard(parent, name, cframe, size, title)
	local board = makePart({
		Name = name,
		Parent = parent,
		Size = Vector3.new(size.X, size.Y, 0.4),
		CFrame = cframe,
		Color = HubConfig.COLORS.Pillar,
		Material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 36)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = HubConfig.COLORS.Neon
	titleLabel.TextSize = 22
	titleLabel.Text = title
	titleLabel.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -12, 1, -44)
	body.Position = UDim2.fromOffset(6, 40)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(220, 225, 240)
	body.TextSize = 18
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "..."
	body.Parent = frame

	return board
end

local function addPrompt(parent, name, actionText, objectText, holdDuration)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "PlazaFloor",
		Parent = hub,
		Size = Vector3.new(HubConfig.PLAZA_RADIUS * 2, 1, HubConfig.PLAZA_RADIUS * 2),
		CFrame = CFrame.new(0, HubConfig.FLOOR_Y - 0.5, 0),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	local ring = makePart({
		Name = "PlazaRing",
		Parent = hub,
		Size = Vector3.new(HubConfig.PLAZA_RADIUS * 2 - 4, 0.2, HubConfig.PLAZA_RADIUS * 2 - 4),
		CFrame = CFrame.new(0, HubConfig.FLOOR_Y + 0.1, 0),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local spawnPad = makePart({
		Name = "SpawnPad",
		Parent = hub,
		Size = Vector3.new(14, 0.6, 14),
		CFrame = CFrame.new(0, HubConfig.FLOOR_Y + 0.3, 0),
		Color = HubConfig.COLORS.SpawnPad,
		Material = Enum.Material.Glass,
	})
	spawnPad:SetAttribute("HubSpawn", true)

	local spawnLight = Instance.new("PointLight")
	spawnLight.Color = HubConfig.COLORS.Neon
	spawnLight.Brightness = 2
	spawnLight.Range = 18
	spawnLight.Parent = spawnPad

	for i = 0, 3 do
		local angle = math.rad(i * 90 + 45)
		local dist = HubConfig.PLAZA_RADIUS - 3
		local pos = Vector3.new(math.sin(angle) * dist, HubConfig.FLOOR_Y + 6, -math.cos(angle) * dist)
		local pillar = makePart({
			Name = "Pillar_" .. i,
			Parent = hub,
			Size = Vector3.new(2.5, 12, 2.5),
			CFrame = CFrame.new(pos),
			Color = HubConfig.COLORS.Pillar,
			Material = Enum.Material.Concrete,
		})
		local light = Instance.new("PointLight")
		light.Color = i % 2 == 0 and HubConfig.COLORS.Neon or HubConfig.COLORS.NeonAlt
		light.Brightness = 1.5
		light.Range = 14
		light.Parent = pillar
		addNeonTrim(hub, pillar.CFrame * CFrame.new(0, 6.1, 0), Vector3.new(2.8, 0.3, 2.8))
	end

	-- Arena archway (north)
	local arenaPos = HubConfig.getZonePosition("Arena")
	local arch = makePart({
		Name = "ArenaGate",
		Parent = hub,
		Size = Vector3.new(12, 10, 2),
		CFrame = CFrame.new(arenaPos + Vector3.new(0, 5, 0)),
		Color = HubConfig.COLORS.Pillar,
		Material = Enum.Material.Metal,
	})
	addNeonTrim(hub, arch.CFrame * CFrame.new(0, 4.5, -1.1), Vector3.new(10, 0.4, 0.3))

	local arenaPrompt = addPrompt(
		arch,
		"ArenaPrompt",
		HubConfig.ZONES.Arena.prompt,
		HubConfig.ZONES.Arena.label,
		0
	)
	arenaPrompt:SetAttribute("HubAction", "EnterArena")

	local walkGap = makePart({
		Name = "ArenaWalkThrough",
		Parent = hub,
		Size = Vector3.new(8, 8, 2),
		CFrame = arch.CFrame,
		Transparency = 1,
		CanCollide = false,
	})
	walkGap.CanQuery = false
	walkGap.CanTouch = false

	-- Bey garage (east)
	local beyPos = HubConfig.getZonePosition("BeySelect")
	local garage = makePart({
		Name = "BeyGarage",
		Parent = hub,
		Size = Vector3.new(10, 6, 8),
		CFrame = CFrame.new(beyPos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(-90), 0),
		Color = HubConfig.COLORS.Pillar,
		Material = Enum.Material.Metal,
	})
	local beyPrompt = addPrompt(
		garage,
		"BeyPrompt",
		HubConfig.ZONES.BeySelect.prompt,
		HubConfig.ZONES.BeySelect.label,
		0
	)
	beyPrompt:SetAttribute("HubAction", "OpenBeySelect")

	-- Stats board (south)
	local statsPos = HubConfig.getZonePosition("Stats")
	local statsBoard = addBoard(
		hub,
		"StatsBoard",
		CFrame.new(statsPos + Vector3.new(0, 4, 0)),
		HubConfig.BOARD_SIZE,
		"Deine Stats"
	)
	statsBoard.CFrame = CFrame.new(statsPos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(180), 0)
	addPrompt(statsBoard, "StatsPrompt", HubConfig.ZONES.Stats.prompt, HubConfig.ZONES.Stats.label, 0)

	-- Leaderboard board (west)
	local lbPos = HubConfig.getZonePosition("Leaderboard")
	local lbBoard = addBoard(
		hub,
		"LeaderboardBoard",
		CFrame.new(lbPos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(90), 0),
		HubConfig.LEADERBOARD_SIZE,
		"Top 5 Rangliste"
	)
	addPrompt(lbBoard, "LeaderboardPrompt", HubConfig.ZONES.Leaderboard.prompt, HubConfig.ZONES.Leaderboard.label, 0)

	-- Low boundary wall
	for i = 0, 15 do
		local angle = math.rad(i * (360 / 16))
		local dist = HubConfig.PLAZA_RADIUS + 1
		local pos = Vector3.new(math.sin(angle) * dist, HubConfig.FLOOR_Y + 2, -math.cos(angle) * dist)
		makePart({
			Name = "Boundary_" .. i,
			Parent = hub,
			Size = Vector3.new(6, 4, 1),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0),
			Color = HubConfig.COLORS.FloorAccent,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = HubConfig.getSpawnCFrame()
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = hub

	hub.PrimaryPart = spawnPad

	return {
		Model = hub,
		Spawn = spawn,
		SpawnPad = spawnPad,
		ArenaGate = arch,
		ArenaPrompt = arenaPrompt,
		StatsBoard = statsBoard,
		LeaderboardBoard = lbBoard,
		BeyGarage = garage,
	}
end

return HubWorldBuilder
