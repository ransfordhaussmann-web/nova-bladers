local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub

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

local function sendHubState(player, phase)
	HubState:FireClient(player, {
		phase = phase,
		modeLabel = getModeLabel(),
		queuedModeId = MatchmakingService.getQueuedMode(player),
	})
end

local function enterHub(player)
	playerPhase[player] = "hub"
	MatchmakingService.leaveQueue(player)
	teleportToHub(player)
	sendLobbyReady(player)
	sendHubState(player, "hub")
	ReturnToHub:FireClient(player)
end

local function enterQueue(player, modeId)
	if playerPhase[player] == "arena" then
		return
	end
	if not MatchmakingConfig.isValidMode(modeId) then
		return
	end

	playerPhase[player] = "queuing"
	MatchmakingService.joinQueue(player, modeId)
	sendHubState(player, "queuing")
end

local function leaveQueue(player)
	if playerPhase[player] ~= "queuing" then
		return
	end
	MatchmakingService.leaveQueue(player)
	playerPhase[player] = "hub"
	sendHubState(player, "hub")
end

local function leaveHubForArena(player)
	if playerPhase[player] == "arena" then
		return
	end
	MatchmakingService.leaveQueue(player)
	playerPhase[player] = "arena"
	sendHubState(player, "arena")
end

local function enterArenaForMatch(players)
	for _, player in players do
		leaveHubForArena(player)
	end
end

local function onEnterArena(player)
	enterQueue(player, getActiveModeId())
end

hub.portalPrompt.Triggered:Connect(function(player)
	onEnterArena(player)
end)

for _, pad in hub.modePads do
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QueuePrompt"
	prompt.ActionText = "Warteschlange"
	prompt.ObjectText = pad.config.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad.part

	prompt.Triggered:Connect(function(player)
		enterQueue(player, pad.config.id)
	end)
end

EnterArena.OnServerEvent:Connect(function(player)
	onEnterArena(player)
end)

MatchmakingService.setOnQueueChanged(function(player, modeId)
	if modeId then
		playerPhase[player] = "queuing"
		sendHubState(player, "queuing")
	else
		if playerPhase[player] == "queuing" then
			playerPhase[player] = "hub"
			sendHubState(player, "hub")
		end
	end
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	enterHub(player)
end)

local function getPhase(player)
	return playerPhase[player]
end

local function isInHub(player)
	local phase = playerPhase[player]
	return phase == "hub" or phase == "queuing"
end

HubService.register({
	returnToHub = enterHub,
	getPhase = getPhase,
	isInHub = isInHub,
	enterArenaForMatch = enterArenaForMatch,
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

print("[HubManager] 3D Hub ready — walk to Arena Portal to play")
