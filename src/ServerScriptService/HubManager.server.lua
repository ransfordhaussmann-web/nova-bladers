local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingQueue = require(script.Parent.MatchmakingQueue)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub
local JoinQueue = Remotes.JoinQueue
local LeaveQueue = Remotes.LeaveQueue
local QueueUpdate = Remotes.QueueUpdate
local EnterArenaBindable = Bindables.EnterArena

local hub = HubBuilder.build()
local playerPhase = {}

local function getActiveModeId()
	local count = #Players:GetPlayers()
	return MatchmakingConfig.getRecommendedMode(count)
end

local function getModeLabel()
	return "Modus: " .. MatchmakingConfig.getModeLabel(getActiveModeId())
end

local function updateModePads()
	local activeId = getActiveModeId()
	for _, pad in hub.modePads do
		pad.setActive(pad.config.id == activeId)
	end
end

local function formatLeaderboard(entries)
	local lines = { "🏆 Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rank = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local queueMode = MatchmakingQueue.getPlayerMode(player)
	local queueSnapshot = queueMode and MatchmakingQueue.getQueueSnapshot(queueMode, player) or nil

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		activeModeId = getActiveModeId(),
		leaderboard = leaderboard,
		inHub = playerPhase[player] == "hub",
		inQueue = playerPhase[player] == "queue",
		queueMode = queueMode,
		queueSnapshot = queueSnapshot,
	}
end

local function updateLeaderboardDisplay()
	local text = formatLeaderboard(LeaderboardManager.getTop(5))
	hub.leaderboardText.Text = text
end

local function sendLobbyReady(player)
	local payload = buildLobbyPayload(player)
	LobbyReady:FireClient(player, payload)
	updateLeaderboardDisplay()
end

local function broadcastLobbyUpdate()
	updateModePads()
	updateLeaderboardDisplay()
	for _, player in Players:GetPlayers() do
		if playerPhase[player] == "hub" or playerPhase[player] == "queue" then
			sendLobbyReady(player)
		end
	end
end

local function enableCharacterMovement(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = HubConfig.WALK_SPEED
		humanoid.JumpPower = 50
	end
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = hub.spawnCFrame
	end
	enableCharacterMovement(character)
end

local function sendHubState(player, phase)
	HubState:FireClient(player, {
		phase = phase,
		modeLabel = getModeLabel(),
		queueMode = MatchmakingQueue.getPlayerMode(player),
	})
end

local function enterHub(player)
	MatchmakingQueue.leave(player)
	playerPhase[player] = "hub"
	teleportToHub(player)
	sendLobbyReady(player)
	sendHubState(player, "hub")
	ReturnToHub:FireClient(player)
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "arena" then
		return false
	end

	local joined = MatchmakingQueue.join(player, modeId)
	if not joined then
		return false
	end

	playerPhase[player] = "queue"
	sendHubState(player, "queue")
	sendLobbyReady(player)

	local snapshot = MatchmakingQueue.getQueueSnapshot(modeId)
	if snapshot then
		QueueUpdate:FireClient(player, snapshot)
	end
	return true
end

local function leaveQueue(player)
	if playerPhase[player] ~= "queue" then
		return
	end
	MatchmakingQueue.leave(player)
	playerPhase[player] = "hub"
	sendHubState(player, "hub")
	sendLobbyReady(player)
end

local function leaveHubForArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	MatchmakingQueue.leave(player)
	playerPhase[player] = "arena"
	sendHubState(player, "arena")
end

local function onEnterArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	if playerPhase[player] == "queue" then
		return
	end
	enterQueue(player, getActiveModeId())
end

local function onJoinQueueRequest(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.QUEUES[modeId] then
		return
	end
	if playerPhase[player] == "arena" then
		return
	end
	enterQueue(player, modeId)
end

hub.portalPrompt.Triggered:Connect(function(player)
	onEnterArena(player)
end)

for _, pad in hub.modePads do
	pad.queuePrompt.Triggered:Connect(function(player)
		onJoinQueueRequest(player, pad.config.id)
	end)
end

EnterArena.OnServerEvent:Connect(function(player)
	onEnterArena(player)
end)

JoinQueue.OnServerEvent:Connect(onJoinQueueRequest)

LeaveQueue.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

local function isInQueue(player)
	return playerPhase[player] == "queue"
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	isInQueue = isInQueue,
})

MatchmakingQueue.init(Remotes, function(matchPlayers, modeId)
	for _, player in matchPlayers do
		leaveHubForArena(player)
	end
	EnterArenaBindable:Fire(matchPlayers, modeId)
end)

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	playerPhase[player] = "hub"

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if playerPhase[player] == "hub" or playerPhase[player] == "queue" then
				teleportToHub(player)
				enableCharacterMovement(character)
			end
		end)
	end)

	enterHub(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	broadcastLobbyUpdate()
end)

Players.PlayerRemoving:Connect(function(player)
	playerPhase[player] = nil
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

print("[HubManager] 3D Hub + Matchmaking-Queue ready")
