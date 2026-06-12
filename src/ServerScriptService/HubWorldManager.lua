local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local HubWorldManager = {}

local hubFolder
local arenaFolder
local playerZone = {}
local initialized = false

local function getRemotes()
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	return nova:WaitForChild("Remotes")
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = HubWorldConfig.PROMPT.MAX_DISTANCE
	prompt.HoldDuration = HubWorldConfig.PROMPT.HOLD_DURATION
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function addLabel(parent, text, size)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(235, 245, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui

	if size then
		gui.CanvasSize = size
	end

	return gui
end

function HubWorldManager.buildHub()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = Workspace:FindFirstChild(HubWorldConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	local origin = HubWorldConfig.HUB_ORIGIN
	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubWorldConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = makePart({
		Name = "HubFloor",
		Size = HubWorldConfig.HUB_FLOOR_SIZE,
		Position = origin + Vector3.new(0, -HubWorldConfig.HUB_FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(42, 48, 62),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hubFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + HubWorldConfig.SPAWN_OFFSET
	spawn.Color = Color3.fromRGB(90, 160, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = hubFolder

	local ring = makePart({
		Name = "HubRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 52, 52),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 120, 220),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	ring.Parent = hubFolder

	local gate = makePart({
		Name = "ArenaGate",
		Size = Vector3.new(10, 12, 2),
		Position = origin + HubWorldConfig.ARENA_GATE_OFFSET + Vector3.new(0, 6, 0),
		Color = Color3.fromRGB(255, 170, 60),
		Material = Enum.Material.Metal,
	})
	gate.Parent = hubFolder
	addPrompt(gate, HubWorldConfig.PROMPT.ARENA_ACTION, "Nova Arena")
	addLabel(gate, "NOVA ARENA", Vector2.new(400, 200))

	local beyPodium = makePart({
		Name = "BeySelectPodium",
		Size = Vector3.new(8, 3, 8),
		Position = origin + HubWorldConfig.BEY_SELECT_OFFSET + Vector3.new(0, 1.5, 0),
		Color = Color3.fromRGB(120, 90, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	beyPodium.Parent = hubFolder
	addPrompt(beyPodium, HubWorldConfig.PROMPT.BEY_ACTION, "Bey Garage")
	addLabel(beyPodium, "BEY GARAGE", Vector2.new(320, 120))

	local statsBoard = makePart({
		Name = "StatsBoard",
		Size = Vector3.new(10, 8, 1),
		Position = origin + HubWorldConfig.STATS_BOARD_OFFSET + Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.SmoothPlastic,
	})
	statsBoard.Parent = hubFolder
	addPrompt(statsBoard, HubWorldConfig.PROMPT.STATS_ACTION, "Rangliste")
	addLabel(statsBoard, "STATS", Vector2.new(400, 320))

	for index = 1, 4 do
		local angle = (index - 1) * (math.pi / 2)
		local pillar = makePart({
			Name = "Pillar" .. index,
			Size = Vector3.new(2, 14, 2),
			Position = origin + Vector3.new(math.cos(angle) * 34, 7, math.sin(angle) * 34),
			Color = Color3.fromRGB(55, 62, 78),
			Material = Enum.Material.Concrete,
		})
		pillar.Parent = hubFolder
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 60
	light.Color = Color3.fromRGB(180, 210, 255)
	light.Parent = floor

	return hubFolder
end

function HubWorldManager.getArenaFolder()
	if arenaFolder and arenaFolder.Parent then
		return arenaFolder
	end
	arenaFolder = Workspace:FindFirstChild(HubWorldConfig.ARENA_FOLDER_NAME)
	return arenaFolder
end

function HubWorldManager.getHubSpawnCFrame()
	HubWorldManager.buildHub()
	local spawn = hubFolder:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubWorldConfig.HUB_ORIGIN + HubWorldConfig.SPAWN_OFFSET)
end

function HubWorldManager.getArenaSpawnCFrame()
	local arena = HubWorldManager.getArenaFolder()
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
			or arena:FindFirstChild("ArenaSpawn", true)
			or arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		if spawn and spawn:IsA("SpawnLocation") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubWorldConfig.HUB_ORIGIN - Vector3.new(0, 100, 0))
end

function HubWorldManager.isInArena(player)
	return playerZone[player] == "arena"
end

function HubWorldManager.teleportPlayer(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(targetCFrame)
end

function HubWorldManager.sendToArena(player)
	playerZone[player] = "arena"
	local arena = HubWorldManager.getArenaFolder()
	if arena then
		local arenaSpawn = arena:FindFirstChild("Spawn", true)
			or arena:FindFirstChild("ArenaSpawn", true)
			or arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if arenaSpawn and arenaSpawn:IsA("SpawnLocation") then
			player.RespawnLocation = arenaSpawn
		end
	end
	HubWorldManager.teleportPlayer(player, HubWorldManager.getArenaSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	playerZone[player] = "hub"
	local hubSpawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if hubSpawn and hubSpawn:IsA("SpawnLocation") then
		player.RespawnLocation = hubSpawn
	end
	HubWorldManager.teleportPlayer(player, HubWorldManager.getHubSpawnCFrame())
end

function HubWorldManager.spawnInHub(player)
	playerZone[player] = "hub"
	player.RespawnLocation = hubFolder and hubFolder:FindFirstChild("HubSpawn") or nil

	local function placeCharacter(character)
		task.defer(function()
			HubWorldManager.teleportPlayer(player, HubWorldManager.getHubSpawnCFrame())
		end)
	end

	if player.Character then
		placeCharacter(player.Character)
	end
	player.CharacterAdded:Connect(placeCharacter)
end

function HubWorldManager.init()
	if initialized then
		return
	end
	initialized = true
	HubWorldManager.buildHub()
end

function HubWorldManager.onPlayerAdded(player, lobbyPayloadFn)
	HubWorldManager.spawnInHub(player)
	if lobbyPayloadFn then
		task.defer(function()
			local remotes = getRemotes()
			remotes.LobbyReady:FireClient(player, lobbyPayloadFn(player))
		end)
	end
end

return HubWorldManager
