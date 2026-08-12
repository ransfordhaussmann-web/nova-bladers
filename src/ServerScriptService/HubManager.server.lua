local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local JoinQueue = Remotes.JoinQueue
local LeaveQueue = Remotes.LeaveQueue
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub

local hub = HubBuilder.build()
local playerPhase = {}

local function getModeLabelForId(modeId)
	local rules = HubConfig.QUEUE_RULES[modeId]
	if rules then
		return "Modus: " .. rules.label
	end
	return "Modus: Training"
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function updateModePads(activeModeId)
	for _, pad in hub.modePads do
		pad.setActive(pad.config.id == activeModeId)
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
	local queuedModeId = MatchmakingService.getPlayerMode(player)
	local activeModeId = queuedModeId or getRecommendedModeId()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabelForId(activeModeId),
		activeModeId = activeModeId,
		queuedModeId = queuedModeId,
		inQueue = MatchmakingService.isQueued(player),
		leaderboard = leaderboard,
		inHub = playerPhase[player] == "hub" or playerPhase[player] == "queued",
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
	updateLeaderboardDisplay()
	for _, player in Players:GetPlayers() do
		if playerPhase[player] == "hub" or playerPhase[player] == "queued" then
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
	MatchmakingService.leaveQueue(player)
	playerPhase[player] = "hub"
	teleportToHub(player)
	sendLobbyReady(player)
	updateModePads(getRecommendedModeId())
	HubState:FireClient(player, {
		phase = "hub",
		modeLabel = getModeLabelForId(getRecommendedModeId()),
	})
	ReturnToHub:FireClient(player)
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "match" then
		return
	end

	local resolvedMode = modeId or getRecommendedModeId()
	if not MatchmakingService.joinQueue(player, resolvedMode) then
		return
	end

	playerPhase[player] = "queued"
	sendLobbyReady(player)
	updateModePads(resolvedMode)
	HubState:FireClient(player, {
		phase = "queued",
		modeId = resolvedMode,
		modeLabel = getModeLabelForId(resolvedMode),
	})
end

local function leaveQueue(player)
	if not MatchmakingService.isQueued(player) then
		return
	end

	MatchmakingService.leaveQueue(player)
	playerPhase[player] = "hub"
	sendLobbyReady(player)
	updateModePads(getRecommendedModeId())
	HubState:FireClient(player, {
		phase = "hub",
		modeLabel = getModeLabelForId(getRecommendedModeId()),
	})
end

local function enterMatch(player)
	playerPhase[player] = "match"
	HubState:FireClient(player, {
		phase = "match",
		modeLabel = getModeLabelForId(getRecommendedModeId()),
	})
end

hub.portalPrompt.ActionText = "Warteschlange"
hub.portalPrompt.ObjectText = "Arena Matchmaking"

hub.portalPrompt.Triggered:Connect(function(player)
	enterQueue(player, getRecommendedModeId())
end)

for _, pad in hub.modePads do
	pad.prompt.Triggered:Connect(function(player)
		enterQueue(player, pad.config.id)
	end)
end

EnterArena.OnServerEvent:Connect(function(player)
	enterQueue(player, getRecommendedModeId())
end)

JoinQueue.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		enterQueue(player, getRecommendedModeId())
		return
	end
	enterQueue(player, modeId)
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	enterMatch = enterMatch,
})

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	playerPhase[player] = "hub"

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if playerPhase[player] == "hub" or playerPhase[player] == "queued" then
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

print("[HubManager] 3D Hub ready — use mode pads or portal to join matchmaking")
