local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(60, 60, 70)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function makeZoneBuilding(parent, zoneDef, origin)
	local center = origin + zoneDef.offset
	local building = Instance.new("Model")
	building.Name = zoneDef.id
	building.Parent = parent

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(zoneDef.size.X, 1, zoneDef.size.Z),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color = zoneDef.color:lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Concrete,
		Parent = building,
	})

	local wallHeight = zoneDef.size.Y
	local halfX = zoneDef.size.X / 2
	local halfZ = zoneDef.size.Z / 2
	local wallThickness = 1

	local walls = {
		{ offset = Vector3.new(0, wallHeight / 2, halfZ), size = Vector3.new(zoneDef.size.X, wallHeight, wallThickness) },
		{ offset = Vector3.new(0, wallHeight / 2, -halfZ), size = Vector3.new(zoneDef.size.X, wallHeight, wallThickness) },
		{ offset = Vector3.new(halfX, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, zoneDef.size.Z) },
		{ offset = Vector3.new(-halfX, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, zoneDef.size.Z) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wall.size,
			CFrame = CFrame.new(center + wall.offset),
			Color = zoneDef.color,
			Material = Enum.Material.Metal,
			Parent = building,
		})
	end

	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(zoneDef.size.X * 0.7, 2.5, 0.4),
		CFrame = CFrame.new(center + Vector3.new(0, wallHeight + 1.5, halfZ - 0.5)),
		Color = zoneDef.color,
		Material = Enum.Material.Neon,
		Parent = building,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextScaled = true
	signLabel.Text = zoneDef.label
	signLabel.Parent = signGui

	local promptAnchor = makePart({
		Name = "PromptAnchor",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(center + Vector3.new(0, 3, 0)),
		Color = zoneDef.color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = building,
	})
	promptAnchor.Transparency = 0.35

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.promptAction
	prompt.ObjectText = zoneDef.promptObjectText
	prompt.MaxActivationDistance = HubConfig.PROMPT.maxActivationDistance
	prompt.HoldDuration = HubConfig.PROMPT.holdDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	if zoneDef.glowColor then
		local glow = Instance.new("PointLight")
		glow.Color = zoneDef.glowColor
		glow.Brightness = 2
		glow.Range = 14
		glow.Parent = promptAnchor
	end

	building:SetAttribute("ZoneId", zoneDef.id)
	return building, floor
end

local function makeBoard(parent, name, position, rotationY)
	local board = makePart({
		Name = name,
		Size = HubConfig.BOARD.size,
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotationY), 0),
		Color = Color3.fromRGB(18, 22, 32),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 240)
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "BoardText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(230, 235, 255)
	label.TextSize = 22
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = name
	label.Parent = gui

	return board, label
end

function HubWorldBuilder.build(workspaceRoot)
	local existing = workspaceRoot:FindFirstChild(HubConfig.MODEL_NAME)
	if existing then
		existing:Destroy()
	end

	local origin = HubConfig.ORIGIN
	local hub = Instance.new("Model")
	hub.Name = HubConfig.MODEL_NAME
	hub.Parent = workspaceRoot

	local floor = makePart({
		Name = "HubFloor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(origin + Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2, 0)),
		Color = HubConfig.FLOOR_COLOR,
		Material = HubConfig.FLOOR_MATERIAL,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneDef in HubConfig.ZONES do
		local zoneModel = makeZoneBuilding(zonesFolder, zoneDef, origin)
		zoneModel.Parent = zonesFolder
	end

	local boardsFolder = Instance.new("Folder")
	boardsFolder.Name = "Boards"
	boardsFolder.Parent = hub

	local hallZone = HubConfig.ZONES.HallOfFame
	local hallBoardPos = origin + hallZone.offset + HubConfig.BOARD.offset
	local _, leaderboardLabel = makeBoard(boardsFolder, "LeaderboardBoard", hallBoardPos, 180)

	local beyZone = HubConfig.ZONES.BeyLab
	local beyBoardPos = origin + beyZone.offset + HubConfig.BOARD.offset
	local _, beyInfoLabel = makeBoard(boardsFolder, "BeyInfoBoard", beyBoardPos, 0)

	local welcomePos = origin + Vector3.new(0, 8, -HubConfig.FLOOR_SIZE.Z / 2 + 6)
	local _, welcomeLabel = makeBoard(boardsFolder, "WelcomeBoard", welcomePos, 0)
	welcomeLabel.Text = "Nova Bladers\nWillkommen im Hub!\nArena · Bey-Labor · Ruhmeshalle"

	local refs = Instance.new("Folder")
	refs.Name = "Refs"
	refs.Parent = hub

	local spawnRef = Instance.new("ObjectValue")
	spawnRef.Name = "SpawnLocation"
	spawnRef.Value = spawn
	spawnRef.Parent = refs

	local arenaRef = Instance.new("ObjectValue")
	arenaRef.Name = "ArenaGate"
	arenaRef.Value = zonesFolder:FindFirstChild("ArenaGate")
	arenaRef.Parent = refs

	local leaderboardRef = Instance.new("ObjectValue")
	leaderboardRef.Name = "LeaderboardLabel"
	leaderboardRef.Value = leaderboardLabel
	leaderboardRef.Parent = refs

	local beyInfoRef = Instance.new("ObjectValue")
	beyInfoRef.Name = "BeyInfoLabel"
	beyInfoRef.Value = beyInfoLabel
	beyInfoRef.Parent = refs

	hub:SetAttribute("Built", true)
	return hub, {
		spawn = spawn,
		leaderboardLabel = leaderboardLabel,
		beyInfoLabel = beyInfoLabel,
		zonesFolder = zonesFolder,
		floor = floor,
	}
end

return HubWorldBuilder
