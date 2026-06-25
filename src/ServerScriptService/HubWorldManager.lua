local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerState = {}
local lastInteract = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local state = playerState[player]
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = state and state.inHub or false,
		inArena = state and state.inArena or false,
	}
end

local function sendLobbyReady(player, options)
	options = options or {}
	local payload = buildLobbyPayload(player)
	if options.showStatsPanel then
		payload.showStatsPanel = true
	end
	remotes.LobbyReady:FireClient(player, payload)
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local look = HubConfig.SPAWN_LOOK
	root.CFrame = CFrame.lookAt(HubConfig.SPAWN_POSITION, HubConfig.SPAWN_POSITION + look)
end

local function getNearestZone(position)
	local nearest
	local nearestDist = HubConfig.INTERACT_RADIUS
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end
	return nearest
end

function HubWorldManager.isInHub(player)
	local state = playerState[player]
	return state and state.inHub
end

function HubWorldManager.enterArena(player)
	local state = playerState[player]
	if not state or not state.inHub then return end

	state.inHub = false
	state.inArena = true
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	local state = playerState[player]
	if not state then
		playerState[player] = { inHub = true, inArena = false }
	else
		state.inHub = true
		state.inArena = false
	end

	teleportToHub(player)
	sendLobbyReady(player)
end

local function handleZoneAction(player, zone)
	if zone.action == "enter_arena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "show_stats" then
		sendLobbyReady(player, { showStatsPanel = true })
	end
end

local function onHubInteract(player)
	local state = playerState[player]
	if not state or not state.inHub then return end

	local now = os.clock()
	if lastInteract[player] and now - lastInteract[player] < HubConfig.INTERACT_COOLDOWN then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zone = getNearestZone(root.Position)
	if not zone then return end

	lastInteract[player] = now
	handleZoneAction(player, zone)
end

local function onEnterArena(player)
	HubWorldManager.enterArena(player)
end

local function onPlayerAdded(player)
	playerState[player] = { inHub = true, inArena = false }
	PlayerDataManager.load(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		local state = playerState[player]
		if state and state.inHub then
			teleportToHub(player)
		end
	end)

	if player.Character then
		teleportToHub(player)
	end

	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
	lastInteract[player] = nil
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder

	remotes.HubInteract.OnServerEvent:Connect(onHubInteract)
	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
	_G.NovaBladersEnterArena = function(player)
		HubWorldManager.enterArena(player)
	end
end

return HubWorldManager
