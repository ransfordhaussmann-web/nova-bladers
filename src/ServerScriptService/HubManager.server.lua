local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub
local JoinQueue = Remotes.JoinQueue
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
	local queuedMode = MatchmakingService.getPlayerMode(player)
	local queueCounts = MatchmakingService.getQueueCounts()
	local queueState = nil
	if queuedMode then
		local modeConfig = MatchmakingConfig.MODES[queuedMode]
		queueState = {
			inQueue = true,
			modeId = queuedMode,
			modeLabel = modeConfig and modeConfig.label or queuedMode,
			playersInQueue = queueCounts[queuedMode] or 0,
			playersNeeded = modeConfig and modeConfig.minPlayers or 1,
		}
	end
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		activeModeId = getActiveModeId(),
		leaderboard = leaderboard,
		inHub = true,
		queueState = queueState,
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

local function leaveHubForArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	playerPhase[player] = "arena"
	HubState:FireClient(player, { phase = "arena", modeLabel = getModeLabel() })
end

local function joinQueueForMode(player, modeId)
	if playerPhase[player] ~= "hub" then
		return
	end
	if MatchmakingService.joinQueue(player, modeId) then
		sendLobbyReady(player)
	end
end

local function onEnterArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	joinQueueForMode(player, getActiveModeId())
end

for _, pad in hub.modePads do
	pad.prompt.Triggered:Connect(function(player)
		joinQueueForMode(player, pad.config.id)
	end)
end

hub.portalPrompt.Triggered:Connect(function(player)
	onEnterArena(player)
end)

EnterArena.OnServerEvent:Connect(function(player)
	onEnterArena(player)
end)

JoinQueue.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueueForMode(player, modeId)
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	if playerPhase[player] ~= "hub" then
		return
	end
	if MatchmakingService.leaveQueue(player) then
		sendLobbyReady(player)
	end
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	leaveHubForArena = leaveHubForArena,
})

MatchmakingService.setOnMatchReady(function(modeId, playerList)
	for _, player in playerList do
		if player.Parent and playerPhase[player] == "hub" then
			leaveHubForArena(player)
		end
	end
	EnterArenaBindable:Fire(modeId, playerList)
end)

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
	playerPhase[player] = nil
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

print("[HubManager] 3D Hub ready — Mode-Pads oder Portal für Matchmaking")
