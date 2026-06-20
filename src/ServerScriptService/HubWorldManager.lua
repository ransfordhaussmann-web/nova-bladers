local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playerInArena = {}

local function getArenaSpawnCFrame()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ORIGIN + Vector3.new(0, 6, 80))
end

local function getHubSpawnCFrame()
	if hubModel and hubModel:FindFirstChild("HubSpawn") then
		return hubModel.HubSpawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
end

function HubWorldManager.onPlayerReady(player)
	playerInArena[player] = false
	sendLobbyReady(player)
	HubWorldManager.returnToHub(player)
end

function HubWorldManager.enterArena(player)
	if playerInArena[player] then return end
	playerInArena[player] = true
	teleportCharacter(player, getArenaSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	playerInArena[player] = false
	teleportCharacter(player, getHubSpawnCFrame())
	sendLobbyReady(player)
end

local function handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showHall" then
		sendLobbyReady(player)
		remotes.ShowHallPanel:FireClient(player)
	end
end

function HubWorldManager.bindRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		handleZoneAction(player, zoneId)
	end)
end

function HubWorldManager.isInArena(player)
	return playerInArena[player] == true
end

return HubWorldManager
