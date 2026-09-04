local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubBuilder = require(script.Parent.HubBuilder)
local HubService = require(script.Parent.HubService)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
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

local function enterHub(player)
	MatchmakingService.leave(player)
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

local function joinMatchmaking(player, modeId)
	if playerPhase[player] ~= "hub" then
		return
	end
	local ok, reason = MatchmakingService.join(player, modeId)
	if not ok and reason == "match_busy" then
		Remotes.MatchmakingUpdate:FireClient(player, {
			inQueue = false,
			statusMessage = "Arena ist beschäftigt — bitte kurz warten.",
		})
	end
end

local function onEnterArena(player, modeId)
	if playerPhase[player] == "arena" then
		return
	end
	joinMatchmaking(player, modeId or getActiveModeId())
end

hub.portalPrompt.Triggered:Connect(function(player)
	onEnterArena(player, getActiveModeId())
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
		onEnterArena(player, pad.config.id)
	end)
end

EnterArena.OnServerEvent:Connect(function(player)
	onEnterArena(player, getActiveModeId())
end)

Remotes.MatchmakingJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	onEnterArena(player, modeId)
end)

Remotes.MatchmakingLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leave(player)
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
	enterArena = leaveHubForArena,
})

MatchmakingService.init({
	remotes = Remotes,
	onEnterArena = leaveHubForArena,
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
	MatchmakingService.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	task.defer(broadcastLobbyUpdate)
end)

print("[HubManager] 3D Hub ready — walk to Arena Portal to play")
