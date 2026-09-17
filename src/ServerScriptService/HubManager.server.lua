local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub

local hub = HubBuilder.build()
local playerPhase = {}

local function getRecommendedModeId()
	return MatchmakingService.getRecommendedModeId()
end

local function getModeLabel()
	local mode = MatchModes.get(getRecommendedModeId())
	if mode then
		return "Empfohlen: " .. mode.label
	end
	return "Modus: Training"
end

local function updateModePads()
	local activeId = getRecommendedModeId()
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
		activeModeId = getRecommendedModeId(),
		leaderboard = leaderboard,
		inHub = playerPhase[player] == "hub" or playerPhase[player] == "queued" or playerPhase[player] == "pending",
		queued = MatchmakingService.isQueued(player),
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
		if playerPhase[player] == "hub" or playerPhase[player] == "queued" or playerPhase[player] == "pending" then
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

local function joinQueue(player, modeId)
	if playerPhase[player] == "arena" then
		return
	end
	local resolvedMode = modeId or getRecommendedModeId()
	local ok = MatchmakingService.joinQueue(player, resolvedMode)
	if ok then
		playerPhase[player] = "queued"
		HubState:FireClient(player, { phase = "queued", modeLabel = getModeLabel(), modeId = resolvedMode })
	end
end

hub.portalPrompt.Triggered:Connect(function(player)
	joinQueue(player, getRecommendedModeId())
end)

for _, pad in hub.modePads do
	pad.prompt.Triggered:Connect(function(player)
		joinQueue(player, pad.config.id)
	end)
end

EnterArena.OnServerEvent:Connect(function(player)
	joinQueue(player, getRecommendedModeId())
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
})

MatchmakingService.register({
	canJoinQueue = function(player)
		return playerPhase[player] == "hub" or playerPhase[player] == "queued" or playerPhase[player] == "pending"
	end,
	onJoinQueue = function(player)
		playerPhase[player] = "queued"
	end,
	onLeaveQueue = function(player)
		if playerPhase[player] == "queued" or playerPhase[player] == "pending" then
			playerPhase[player] = "hub"
			sendLobbyReady(player)
			HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
		end
	end,
	onPendingQueue = function(player)
		playerPhase[player] = "pending"
	end,
	onMatchLaunch = function(player)
		leaveHubForArena(player)
	end,
})

MatchmakingService.start()

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	playerPhase[player] = "hub"

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if playerPhase[player] == "hub" or playerPhase[player] == "queued" or playerPhase[player] == "pending" then
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

print("[HubManager] 3D Hub ready — use mode pads or Arena Portal to queue")
