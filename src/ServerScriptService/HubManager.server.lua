local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingQueue = require(script.Parent.MatchmakingQueue)

local Remotes, Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub
local QueueState = Remotes.QueueState
local LeaveQueue = Remotes.LeaveQueue
local EnterArenaBindable = Bindables.EnterArena

local hub = HubBuilder.build()
local playerPhase = {}

local function getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
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
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		activeModeId = getActiveModeId(),
		leaderboard = leaderboard,
		inHub = true,
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
		if playerPhase[player] == "hub" then
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

local function enterHub(player)
	playerPhase[player] = "hub"
	teleportToHub(player)
	sendLobbyReady(player)
	HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
	ReturnToHub:FireClient(player)
end

local function broadcastQueueState()
	local payload = MatchmakingQueue.buildState()
	for _, player in Players:GetPlayers() do
		if playerPhase[player] == "queue" then
			QueueState:FireClient(player, payload)
		end
	end
end

local function enterQueue(player)
	if playerPhase[player] == "queue" or playerPhase[player] == "arena" then
		return
	end
	if not HubService.canJoinQueue() then
		return
	end

	local ok = MatchmakingQueue.join(player)
	if not ok then
		return
	end

	playerPhase[player] = "queue"
	HubState:FireClient(player, { phase = "queue", modeLabel = getModeLabel() })
	broadcastQueueState()
end

local function leaveQueue(player)
	MatchmakingQueue.leave(player)
	if playerPhase[player] == "queue" then
		playerPhase[player] = "hub"
		enterHub(player)
	else
		broadcastQueueState()
	end
end

local function leaveHubForArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	playerPhase[player] = "arena"
	HubState:FireClient(player, { phase = "arena", modeLabel = getModeLabel() })
end

local function onEnterArena(player)
	enterQueue(player)
end

hub.portalPrompt.Triggered:Connect(function(player)
	onEnterArena(player)
end)

EnterArena.OnServerEvent:Connect(function(player)
	onEnterArena(player)
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	if playerPhase[player] == "queue" then
		leaveQueue(player)
	else
		enterHub(player)
	end
end)

local function getPhase(player)
	return playerPhase[player]
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
})

MatchmakingQueue.init({
	config = BeyConfig.MATCHMAKING,
	canJoin = function()
		return HubService.canJoinQueue()
	end,
	broadcast = broadcastQueueState,
	onReady = function(queuedPlayers)
		for _, player in queuedPlayers do
			leaveHubForArena(player)
		end
		EnterArenaBindable:Fire(queuedPlayers)
	end,
})

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	playerPhase[player] = "hub"

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if playerPhase[player] == "hub" then
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
	MatchmakingQueue.leave(player)
	playerPhase[player] = nil
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

print("[HubManager] 3D Hub ready — walk to Arena Portal to play")
