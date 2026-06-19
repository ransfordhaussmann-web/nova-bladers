local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local RemotesSetup = require(NovaBladers.RemotesSetup)
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local playersInHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return workspace:FindFirstChild("ArenaSpawn")
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function isNearZone(player, zoneId)
	local zonePart = HubWorldBuilder.findZonePart(zoneId)
	if not zonePart then return false end
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return (root.Position - zonePart.Position).Magnitude <= HubConfig.ZONE_TRIGGER_RADIUS + 4
end

function HubWorldManager.buildWorld()
	return HubWorldBuilder.build(Vector3.zero)
end

function HubWorldManager.spawnPlayerInHub(player)
	playersInHub[player] = true
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnPlayerInHub(player)
	HubWorldManager.sendLobbyPayload(player, { inHub = true })
end

function HubWorldManager.sendLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = options.inHub == true,
		showStats = options.showStats == true,
	}
	remotes.LobbyReady:FireClient(player, payload)
end

local function handleEnterArena(player)
	if not isNearZone(player, "ArenaGate") then return end
	playersInHub[player] = nil
	local arenaSpawn = findArenaSpawn()
	if arenaSpawn then
		teleportCharacter(player, arenaSpawn.CFrame + Vector3.new(0, 3, 0))
	else
		warn("[HubWorldManager] ArenaSpawn nicht gefunden — Spieler bleibt im Hub")
		playersInHub[player] = true
	end
end

local function handleOpenBeySelect(player)
	if not isNearZone(player, "BeyLab") then return end
	remotes.OpenBeySelect:FireClient(player)
end

local function handleShowStats(player)
	if not isNearZone(player, "HallOfFame") then return end
	HubWorldManager.sendLobbyPayload(player, { inHub = true, showStats = true })
end

local ZONE_HANDLERS = {
	enterArena = handleEnterArena,
	openBeySelect = handleOpenBeySelect,
	showStats = handleShowStats,
}

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldManager.buildWorld()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		handleEnterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		for _, zone in HubConfig.ZONES do
			if zone.id == zoneId and ZONE_HANDLERS[zone.action] then
				if isNearZone(player, zoneId) then
					ZONE_HANDLERS[zone.action](player)
				end
				return
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
	end)
end

function HubWorldManager.onPlayerReady(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.spawnPlayerInHub(player)
	HubWorldManager.sendLobbyPayload(player, { inHub = true })
end

return HubWorldManager
