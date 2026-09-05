local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, _Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub
local MatchQueueJoin = Remotes.MatchQueueJoin
local MatchQueueLeave = Remotes.MatchQueueLeave
local MatchQueueUpdate = Remotes.MatchQueueUpdate

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

local function broadcastQueueUpdate(targetPlayer)
	local players = if targetPlayer then { targetPlayer } else Players:GetPlayers()
	for _, player in players do
		if player.Parent and (playerPhase[player] == "hub" or playerPhase[player] == "queue") then
			MatchQueueUpdate:FireClient(player, MatchmakingService.getStatus(player))
		end
	end
end

local function joinQueue(player, modeId)
	if playerPhase[player] == "arena" then
		return
	end

	if MatchmakingService.joinQueue(player, modeId) then
		playerPhase[player] = "queue"
		HubState:FireClient(player, {
			phase = "queue",
			modeLabel = getModeLabel(),
			queueMode = modeId,
		})
		broadcastQueueUpdate()
	end
end

local function leaveQueue(player)
	if not MatchmakingService.isQueued(player) then
		return
	end

	MatchmakingService.leaveQueue(player)
	if playerPhase[player] == "queue" then
		playerPhase[player] = "hub"
		HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
		ReturnToHub:FireClient(player)
	end
	broadcastQueueUpdate()
end

local function leaveHubForArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	playerPhase[player] = "arena"
	HubState:FireClient(player, { phase = "arena", modeLabel = getModeLabel() })
end

local function onEnterArena(player)
	joinQueue(player, getActiveModeId())
end

local function onModePadQueue(player, modeId)
	joinQueue(player, modeId)
end

hub.portalPrompt.Triggered:Connect(onEnterArena)

for _, pad in hub.modePads do
	pad.prompt.Triggered:Connect(function(player)
		onModePadQueue(player, pad.config.id)
	end)
end

EnterArena.OnServerEvent:Connect(onEnterArena)

MatchQueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end)

MatchQueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	leaveQueue(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

local function preparePlayersForMatch(players)
	for _, player in players do
		leaveHubForArena(player)
	end
end

HubService.register({
	returnToHub = function(player)
		leaveQueue(player)
		enterHub(player)
	end,
	getPhase = getPhase,
	preparePlayersForMatch = preparePlayersForMatch,
	notifyQueueChanged = broadcastQueueUpdate,
})

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
	broadcastQueueUpdate(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	broadcastLobbyUpdate()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
	playerPhase[player] = nil
	PlayerDataManager.save(player)
	task.defer(function()
		broadcastLobbyUpdate()
		broadcastQueueUpdate()
	end)
end)

print("[HubManager] 3D Hub ready — step on mode pads or portal to queue")
