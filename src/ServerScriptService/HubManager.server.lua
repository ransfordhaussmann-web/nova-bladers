local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local MatchConfig = require(ReplicatedStorage.NovaBladers.MatchConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub

MatchmakingService.init()

local hub = HubBuilder.build()
local playerPhase = {}

local function getQueueSizes()
	return MatchmakingService.getQueueSizes()
end

local function getSuggestedModeId()
	local sizes = getQueueSizes()
	if sizes.ffa and sizes.ffa >= 2 then
		return "ffa"
	elseif sizes.pvp and sizes.pvp >= 1 then
		return "pvp"
	end
	return "training"
end

local function getModeLabelForId(modeId)
	local mode = MatchConfig.getMode(modeId)
	return mode and ("Modus: " .. mode.label) or "Modus: Training"
end

local function updateModePads()
	local sizes = getQueueSizes()
	local suggestedId = getSuggestedModeId()

	for _, pad in hub.modePads do
		local modeId = pad.config.id
		local waiting = sizes[modeId] or 0
		local isSuggested = modeId == suggestedId
		pad.setActive(isSuggested)
		if pad.setQueueCount then
			pad.setQueueCount(waiting)
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
	local queuedMode = MatchmakingService.getQueuedMode(player)
	local sizes = getQueueSizes()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = queuedMode and getModeLabelForId(queuedMode) or "Wähle einen Modus",
		activeModeId = queuedMode or getSuggestedModeId(),
		queueSizes = sizes,
		inQueue = MatchmakingService.isInQueue(player),
		queuedModeId = queuedMode,
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
	HubState:FireClient(player, { phase = "hub", modeLabel = "Wähle einen Modus" })
	ReturnToHub:FireClient(player)
	broadcastLobbyUpdate()
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "queued" and MatchmakingService.getQueuedMode(player) == modeId then
		return
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		return
	end

	playerPhase[player] = "queued"
	HubState:FireClient(player, {
		phase = "queued",
		modeLabel = getModeLabelForId(modeId),
		modeId = modeId,
	})
	sendLobbyReady(player)
	broadcastLobbyUpdate()
end

local function onQuickMatch(player)
	if playerPhase[player] == "queued" then
		return
	end

	local ok = MatchmakingService.joinQuickMatch(player)
	if not ok then
		return
	end

	local modeId = MatchmakingService.getQueuedMode(player) or getSuggestedModeId()
	playerPhase[player] = "queued"
	HubState:FireClient(player, {
		phase = "queued",
		modeLabel = getModeLabelForId(modeId),
		modeId = modeId,
	})
	sendLobbyReady(player)
	broadcastLobbyUpdate()
end

hub.portalPrompt.Triggered:Connect(function(player)
	onQuickMatch(player)
end)

for _, pad in hub.modePads do
	if pad.prompt then
		pad.prompt.Triggered:Connect(function(player)
			enterQueue(player, pad.config.id)
		end)
	end
end

EnterArena.OnServerEvent:Connect(function(player)
	onQuickMatch(player)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

MatchmakingService.setOnQueueChanged(function()
	broadcastLobbyUpdate()
end)

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
		if playerPhase[player] == "queued" then
			playerPhase[player] = "hub"
			sendLobbyReady(player)
			HubState:FireClient(player, { phase = "hub", modeLabel = "Wähle einen Modus" })
			broadcastLobbyUpdate()
		end
	end,
	joinQueue = function(player, modeId)
		enterQueue(player, modeId)
		return true
	end,
	joinQuickMatch = onQuickMatch,
	isInQueue = MatchmakingService.isInQueue,
	setMatchPhase = function(player, modeId)
		playerPhase[player] = "arena"
		HubState:FireClient(player, {
			phase = "arena",
			modeLabel = getModeLabelForId(modeId),
			modeId = modeId,
		})
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

print("[HubManager] 3D Hub ready — mode pads and portal join the matchmaking queue")
