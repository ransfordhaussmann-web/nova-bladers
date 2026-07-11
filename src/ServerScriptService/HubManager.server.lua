local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local JoinQueue = Remotes.JoinQueue
local LeaveQueue = Remotes.LeaveQueue
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub

local hub = HubBuilder.build()
local playerPhase = {}

local MODE_LABELS = {
	training = "Modus: Training",
	pvp = "Modus: 1v1 PvP",
	ffa = "Modus: FFA",
}

local function getSuggestedModeId()
	local counts = MatchmakingService.getQueueCounts()
	if counts.ffa and counts.ffa >= 2 then
		return "ffa"
	end
	if counts.pvp and counts.pvp >= 1 then
		return "pvp"
	end
	return "training"
end

local function getActiveModeId()
	local counts = MatchmakingService.getQueueCounts()
	local bestMode = "training"
	local bestCount = 0
	for modeId, count in counts do
		if count > bestCount then
			bestCount = count
			bestMode = modeId
		end
	end
	return bestMode
end

local function getModeLabel()
	return MODE_LABELS[getActiveModeId()] or "Modus: Training"
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
	local queueInfo = MatchmakingService.getPlayerQueue(player)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		activeModeId = getActiveModeId(),
		leaderboard = leaderboard,
		queueCounts = MatchmakingService.getQueueCounts(),
		inQueue = queueInfo ~= nil,
		queueMode = queueInfo and queueInfo.mode,
		inHub = playerPhase[player] == "hub",
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

local function enterHub(player)
	MatchmakingService.leaveQueue(player)
	playerPhase[player] = "hub"
	teleportToHub(player)
	sendLobbyReady(player)
	HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
	ReturnToHub:FireClient(player)
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "arena" then
		return false
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		return false
	end

	playerPhase[player] = "queue"
	local modeCfg = MatchmakingConfig.MODES[modeId]
	HubState:FireClient(player, {
		phase = "queue",
		mode = modeId,
		modeLabel = modeCfg and ("Warteschlange: " .. modeCfg.label) or getModeLabel(),
	})
	broadcastLobbyUpdate()
	return true
end

local function leaveQueueForPlayer(player)
	if MatchmakingService.leaveQueue(player) then
		playerPhase[player] = "hub"
		HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
		sendLobbyReady(player)
		broadcastLobbyUpdate()
	end
end

local function setArenaPhase(player)
	playerPhase[player] = "arena"
	HubState:FireClient(player, { phase = "arena", modeLabel = getModeLabel() })
end

hub.portalPrompt.ActionText = "Warteschlange"
hub.portalPrompt.ObjectText = "Schnell-Match"

hub.portalPrompt.Triggered:Connect(function(player)
	enterQueue(player, getSuggestedModeId())
end)

for _, pad in hub.modePads do
	pad.prompt.Triggered:Connect(function(player)
		enterQueue(player, pad.config.id)
	end)
end

JoinQueue.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "auto" or modeId == "" then
		modeId = getSuggestedModeId()
	end
	if not MatchmakingConfig.MODES[modeId] then
		modeId = "training"
	end
	enterQueue(player, modeId)
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	leaveQueueForPlayer(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

HubService.register({
	returnToHub = enterHub,
	getPhase = function(player)
		return playerPhase[player]
	end,
	setArenaPhase = setArenaPhase,
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
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

print("[HubManager] 3D Hub ready — use Mode Pads or Arena Portal to join matchmaking queue")
