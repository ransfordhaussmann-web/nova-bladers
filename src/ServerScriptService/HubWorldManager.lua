local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local leaderboardBoard
local zoneParts = {}
local playersInHub = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(0, 10, 50)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboard()
	if not leaderboardBoard then return end
	HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, LeaderboardManager.getTop(5))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
	playersInHub[player] = true
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = nil
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = getArenaSpawnCFrame()
end

local function onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		HubWorldManager.teleportToHub(player)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onZoneTriggered(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	remotes.HubZoneAction:FireClient(player, zoneId, zone.action)

	if zone.action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "ShowLeaderboard" then
		HubWorldManager.refreshLeaderboard()
		remotes.HubZoneHint:FireClient(player, zone.name, zone.hint)
	end
end

local function connectZonePrompts()
	for zoneId, part in zoneParts do
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, zoneId)
			end)
		end

		part.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then return end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end
			local zone = HubConfig.ZONES[zoneId]
			if zone then
				remotes.HubZoneHint:FireClient(player, zone.name, zone.hint)
			end
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	_, zoneParts, leaderboardBoard = HubWorldBuilder.build()
	connectZonePrompts()
	HubWorldManager.refreshLeaderboard()

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
