local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playerState = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function getArenaFolder()
	return Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
end

local function getArenaSpawnCFrame()
	local arena = getArenaFolder()
	if not arena then
		return CFrame.new(0, 6, 0)
	end
	local spawn = arena:FindFirstChild("Spawn", true)
		or arena:FindFirstChild("ArenaSpawn", true)
		or arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return arena:GetPivot() + Vector3.new(0, 6, 0)
end

local function getHubSpawnCFrame()
	local spawnPart = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

local function teleportPlayer(player, targetCFrame)
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

local function setArenaVisible(visible)
	local arena = getArenaFolder()
	if arena then
		arena.Parent = visible and Workspace or ReplicatedStorage
	end
end

local function createBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, parent.Size.Y * 0.5 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(210, 210, 220)
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function createZone(zoneId, zoneConfig)
	local part = Instance.new("Part")
	part.Name = zoneId
	part.Anchored = true
	part.CanCollide = true
	part.Size = zoneConfig.size
	part.CFrame = CFrame.new(HubConfig.HUB_ORIGIN + zoneConfig.position)
		+ Vector3.new(0, zoneConfig.size.Y * 0.5, 0)
	part.Color = zoneConfig.color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.25
	part.Parent = hubFolder

	createBillboard(part, zoneConfig.label, zoneConfig.hint)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.label
	prompt.ObjectText = zoneConfig.hint
	prompt.MaxActivationDistance = HubConfig.PROMPT_DISTANCE
	prompt.HoldDuration = HubConfig.PROMPT_HOLD
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		HubWorldManager.handleZoneAction(player, zoneConfig.action)
	end)

	return part
end

function HubWorldManager.buildHubWorld()
	if hubFolder and hubFolder.Parent then
		return hubFolder
	end

	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = Workspace

	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.HUB_ORIGIN + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0)
	floor.Color = Color3.fromRGB(35, 38, 48)
	floor.Material = Enum.Material.Slate
	floor.Parent = hubFolder

	local spawn = Instance.new("Part")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hubFolder

	for zoneId, zoneConfig in HubConfig.ZONES do
		createZone(zoneId, zoneConfig)
	end

	setArenaVisible(false)
	return hubFolder
end

function HubWorldManager.isInArena(player)
	local state = playerState[player]
	return state and state.inArena or false
end

function HubWorldManager.getLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local arenaPlayers = 0
	for otherPlayer, state in playerState do
		if state.inArena and otherPlayer.Parent then
			arenaPlayers += 1
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(math.max(arenaPlayers, 1)),
		leaderboard = leaderboard,
		inHub = not HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.pushLobbyState(player)
	if not remotes then
		return
	end
	local payload = HubWorldManager.getLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, payload)
	remotes.HubState:FireClient(player, payload)
end

function HubWorldManager.pushHubStateToAll()
	for _, player in Players:GetPlayers() do
		if not HubWorldManager.isInArena(player) then
			HubWorldManager.pushLobbyState(player)
		end
	end
end

function HubWorldManager.sendToArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end

	playerState[player] = { inArena = true }
	setArenaVisible(true)
	teleportPlayer(player, getArenaSpawnCFrame())

	local payload = HubWorldManager.getLobbyPayload(player)
	remotes.HubState:FireClient(player, {
		inHub = false,
		modeLabel = payload.modeLabel,
		wins = payload.wins,
		losses = payload.losses,
		rank = payload.rank,
		leaderboard = payload.leaderboard,
	})
	HubWorldManager.pushHubStateToAll()
end

function HubWorldManager.returnToHub(player)
	playerState[player] = { inArena = false }

	local arenaOccupants = 0
	for _, state in playerState do
		if state.inArena then
			arenaOccupants += 1
		end
	end
	if arenaOccupants == 0 then
		setArenaVisible(false)
	end

	teleportPlayer(player, getHubSpawnCFrame())
	HubWorldManager.pushLobbyState(player)
	HubWorldManager.pushHubStateToAll()
end

function HubWorldManager.handleZoneAction(player, action)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "enterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showStats" then
		HubWorldManager.pushLobbyState(player)
		remotes.RefreshHubStats:FireClient(player, HubWorldManager.getLobbyPayload(player))
	end
end

function HubWorldManager.onCharacterAdded(player, character)
	task.defer(function()
		if HubWorldManager.isInArena(player) then
			teleportPlayer(player, getArenaSpawnCFrame())
		else
			teleportPlayer(player, getHubSpawnCFrame())
		end
	end)
end

function HubWorldManager.onPlayerAdded(player)
	playerState[player] = { inArena = false }
	PlayerDataManager.load(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function(character)
		HubWorldManager.onCharacterAdded(player, character)
	end)

	if player.Character then
		HubWorldManager.onCharacterAdded(player, player.Character)
	end

	task.defer(function()
		HubWorldManager.pushLobbyState(player)
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder
	HubWorldManager.buildHubWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		HubWorldManager.pushLobbyState(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
