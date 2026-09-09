local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub

local hub = HubBuilder.build()
local playerPhase = {}
local playerQueueMode = {}

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

local function getModeLabelForId(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode then
		return "Modus: " .. mode.label
	end
	return getModeLabel()
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rank = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local phase = playerPhase[player] or "hub"
	local queueModeId = playerQueueMode[player]
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = queueModeId and getModeLabelForId(queueModeId) or getModeLabel(),
		activeModeId = getActiveModeId(),
		leaderboard = leaderboard,
		inHub = phase == "hub" or phase == "queue",
		inQueue = phase == "queue",
		queueModeId = queueModeId,
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
	playerQueueMode[player] = nil
	teleportToHub(player)
	sendLobbyReady(player)
	HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
	ReturnToHub:FireClient(player)
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "arena" then
		return
	end
	playerPhase[player] = "queue"
	playerQueueMode[player] = modeId
	HubState:FireClient(player, {
		phase = "queue",
		modeId = modeId,
		modeLabel = getModeLabelForId(modeId),
	})
	sendLobbyReady(player)
end

local function leaveQueue(player)
	if playerPhase[player] ~= "queue" then
		return
	end
	playerPhase[player] = "hub"
	playerQueueMode[player] = nil
	HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
	sendLobbyReady(player)
end

local function enterArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	playerPhase[player] = "arena"
	playerQueueMode[player] = nil
	HubState:FireClient(player, { phase = "arena", modeLabel = getModeLabel() })
end

local function joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		modeId = MatchmakingConfig.resolveAutoMode(#Players:GetPlayers())
	end
	HubService.requestJoinQueue(player, modeId)
end

hub.portalPrompt.Triggered:Connect(function(player)
	joinQueue(player, MatchmakingConfig.resolveAutoMode(#Players:GetPlayers()))
end)

for _, pad in hub.modePads do
	pad.queuePrompt.Triggered:Connect(function(player)
		joinQueue(player, pad.config.id)
	end)
end

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	enterQueue = enterQueue,
	leaveQueue = leaveQueue,
	enterArena = enterArena,
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
	playerPhase[player] = nil
	playerQueueMode[player] = nil
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

print("[HubManager] 3D Hub ready — Mode-Pads, Portal oder Lobby-Button für Warteschlange")
