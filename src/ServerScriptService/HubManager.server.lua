local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local MatchmakingQueue = require(script.Parent.MatchmakingQueue)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local LobbyReady = Remotes.LobbyReady
local EnterArena = Remotes.EnterArena
local HubState = Remotes.HubState
local ReturnToHub = Remotes.ReturnToHub
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave

local hub = HubBuilder.build()
local playerPhase = {}
local preferredMode = {}

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
		preferredModeId = preferredMode[player] or getActiveModeId(),
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

local function enterQueue(player)
	if playerPhase[player] == "queue" or playerPhase[player] == "arena" then
		return
	end
	local modeId = preferredMode[player] or getActiveModeId()
	playerPhase[player] = "queue"
	MatchmakingQueue.join(player, modeId)
	HubState:FireClient(player, {
		phase = "queue",
		modeLabel = getModeLabel(),
		modeId = modeId,
	})
end

local function leaveQueue(player)
	if playerPhase[player] ~= "queue" then
		return
	end
	MatchmakingQueue.leave(player)
	playerPhase[player] = "hub"
	HubState:FireClient(player, { phase = "hub", modeLabel = getModeLabel() })
	sendLobbyReady(player)
end

local function enterArenaFromQueue(player)
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

ReturnToHub.OnServerEvent:Connect(function(player)
	leaveQueue(player)
	enterHub(player)
end)

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) == "string" and HubConfig.MODE_REQUIRED[modeId] then
		preferredMode[player] = modeId
	end
	if playerPhase[player] == "hub" then
		enterQueue(player)
	end
end)

QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

for _, pad in hub.modePads do
	pad.part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		preferredMode[player] = pad.config.id
		updateModePads()
		if playerPhase[player] == "hub" then
			sendLobbyReady(player)
		end
	end)
end

MatchmakingQueue.init(function(players, modeId)
	for _, player in players do
		enterArenaFromQueue(player)
	end
	Bindables.StartQueuedMatch:Fire(players, modeId)
end)

local function getPhase(player)
	return playerPhase[player]
end

HubService.register({
	returnToHub = function(player)
		leaveQueue(player)
		enterHub(player)
	end,
	getPhase = getPhase,
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
