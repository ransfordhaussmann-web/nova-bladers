local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playerState = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		hubMode = true,
	}
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(60, 60, 70)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function createZoneLabel(parent, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

local function createZone(zoneConfig)
	local zone = createPart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		Position = zoneConfig.position,
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
		Parent = hubFolder,
	})
	zone.Transparency = 0.35

	createZoneLabel(zone, zoneConfig.label)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.promptText
	prompt.ObjectText = zoneConfig.label
	prompt.HoldDuration = zoneConfig.holdDuration or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone

	prompt.Triggered:Connect(function(player)
		HubWorldManager.handleZoneAction(player, zoneConfig.promptAction)
	end)
end

local function buildWalls(parent, floorSize)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local thick = HubConfig.WALL_THICKNESS
	local center = HubConfig.HUB_FLOOR_POSITION

	local walls = {
		{ Size = Vector3.new(floorSize.X + thick * 2, wallH, thick), Position = center + Vector3.new(0, wallH / 2, -halfZ - thick / 2) },
		{ Size = Vector3.new(floorSize.X + thick * 2, wallH, thick), Position = center + Vector3.new(0, wallH / 2, halfZ + thick / 2) },
		{ Size = Vector3.new(thick, wallH, floorSize.Z), Position = center + Vector3.new(-halfX - thick / 2, wallH / 2, 0) },
		{ Size = Vector3.new(thick, wallH, floorSize.Z), Position = center + Vector3.new(halfX + thick / 2, wallH / 2, 0) },
	}

	for i, wall in walls do
		createPart({
			Name = "Wall" .. i,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(45, 48, 58),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end
end

local function buildHubWorld()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local floor = createPart({
		Name = "Floor",
		Size = HubConfig.HUB_FLOOR_SIZE,
		Position = HubConfig.HUB_FLOOR_POSITION + Vector3.new(0, -HubConfig.HUB_FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
		Parent = hubFolder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hubFolder

	buildWalls(hubFolder, HubConfig.HUB_FLOOR_SIZE)

	for _, zoneConfig in HubConfig.ZONES do
		createZone(zoneConfig)
	end

	return floor
end

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
			or arena:FindFirstChild("ArenaSpawn", true)
			or arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		if arena:IsA("BasePart") then
			return arena.CFrame + Vector3.new(0, 5, 0)
		end
	end
	return CFrame.new(0, 5, 80)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.isInArena(player)
	local state = playerState[player]
	return state and state.inArena == true
end

function HubWorldManager.sendToArena(player)
	playerState[player] = { inArena = true }
	teleportPlayer(player, getArenaSpawnCFrame())

	local hud = player:FindFirstChild("PlayerGui")
	if hud then
		local lobby = hud:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
	end
end

function HubWorldManager.returnToHub(player)
	playerState[player] = { inArena = false }
	teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
	sendLobbyReady(player)
end

function HubWorldManager.handleZoneAction(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowStats" then
		remotes.HubZoneAction:FireClient(player, "ShowStats", buildLobbyPayload(player))
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	playerState[player] = { inArena = false }

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not HubWorldManager.isInArena(player) then
				teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
				sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
	end
	sendLobbyReady(player)
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not HubWorldManager.isInArena(player) then
			HubWorldManager.sendToArena(player)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
