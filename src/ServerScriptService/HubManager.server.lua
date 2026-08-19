local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local JoinQueue = Remotes.JoinQueue
local LeaveQueue = Remotes.LeaveQueue
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub
local EnterArenaBindable = Bindables.EnterArena

local hub = HubBuilder.build()
local playerPhase = {}

local function getActiveModeId()
	return MatchmakingService.getRecommendedMode()
end

local function getModeLabel()
	local modeId = getActiveModeId()
	local pad = HubConfig.MODE_PADS[modeId == "training" and "Training" or (modeId == "pvp" and "PvP" or "FFA")]
	if pad then
		return "Empfohlen: " .. pad.label
	end
	return "Modus: Training"
end

local function updateModePads()
	local activeId = getActiveModeId()
	local counts = MatchmakingService.getQueueCounts()
	for _, pad in hub.modePads do
		local waiting = counts[pad.config.id] or 0
		pad.setActive(pad.config.id == activeId)
		if pad.prompt then
			pad.prompt.ObjectText = string.format("%s (%d wartend)", pad.config.label, waiting)
		end
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
		queueCounts = MatchmakingService.getQueueCounts(),
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
	MatchmakingService.leaveQueue(player)
	playerPhase[player] = "hub"
	teleportToHub(player)
	sendLobbyReady(player)
	HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
	ReturnToHub:FireClient(player)
	broadcastLobbyUpdate()
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "arena" or playerPhase[player] == "queue" then
		return
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		return
	end

	playerPhase[player] = "queue"
	HubState:FireClient(player, {
		phase = "queue",
		modeId = modeId,
		modeLabel = getModeLabel(),
	})
	updateModePads()
end

local function setPhaseArena(player)
	playerPhase[player] = "arena"
	HubState:FireClient(player, { phase = "arena", modeLabel = getModeLabel() })
end

local function onJoinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getActiveModeId()
	end
	enterQueue(player, modeId)
end

hub.portalPrompt.Triggered:Connect(function(player)
	onJoinQueue(player, getActiveModeId())
end)

for _, pad in hub.modePads do
	pad.prompt.Triggered:Connect(function(player)
		onJoinQueue(player, pad.config.id)
	end)
end

JoinQueue.OnServerEvent:Connect(function(player, modeId)
	onJoinQueue(player, modeId)
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

-- Legacy bindable / remote for fallback UI button
EnterArenaBindable.Event:Connect(function(player)
	onJoinQueue(player, getActiveModeId())
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	onJoinQueue(player, getActiveModeId())
end)

local function getPhase(player)
	return playerPhase[player]
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	setPhaseArena = setPhaseArena,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
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
	playerPhase[player] = nil
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

task.spawn(function()
	while true do
		task.wait(1)
		updateModePads()
	end
end)

print("[HubManager] 3D Hub ready — mode pads & portal join matchmaking queue")
