local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local zonePrompts = {}
local inArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		showPanel = showPanel == true,
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPos = HubConfig.ORIGIN + HubConfig.HUB_SPAWN
	root.CFrame = CFrame.new(spawnPos)
	inArena[player] = nil
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	player.CharacterAdded:Connect(function()
		if not inArena[player] then
			task.defer(teleportToHub, player)
		end
	end)
	if player.Character then
		teleportToHub(player)
	end
end

function HubWorldManager.enterArena(player)
	if inArena[player] then return end
	inArena[player] = true

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local arenaPos = HubConfig.ORIGIN + HubConfig.ARENA_SPAWN_OFFSET
	root.CFrame = CFrame.new(arenaPos)

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

local function onHallOfFame(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

local function onBeyLab(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function onArenaGate(player)
	HubWorldManager.enterArena(player)
end

local ZONE_HANDLERS = {
	ArenaGate = onArenaGate,
	BeyLab = onBeyLab,
	HallOfFame = onHallOfFame,
}

local function connectPrompts(prompts)
	for zoneId, prompt in prompts do
		zonePrompts[zoneId] = prompt
		prompt.Triggered:Connect(function(player)
			local handler = ZONE_HANDLERS[zoneId]
			if handler then
				handler(player)
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local _, prompts = HubWorldBuilder.build()
	connectPrompts(prompts)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		HubWorldManager.spawnInHub(player)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		HubWorldManager.spawnInHub(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inArena[player] = nil
	end)
end

return HubWorldManager
