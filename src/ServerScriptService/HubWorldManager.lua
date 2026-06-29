local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubData
local playerZones = {}
local playerInArena = {}
local zoneCheckAccumulator = 0

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT),
	}
end

local function updateLeaderboardBoard()
	if not hubData or not hubData.leaderboardBoard then
		return
	end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	local lines = {"🏆 Top Spieler"}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	hubData.leaderboardBoard.Text = table.concat(lines, "\n")
end

local function getZoneAtPosition(position)
	for _, zone in hubData.zones do
		local trigger = zone.trigger
		local relative = position - trigger.Position
		local half = trigger.Size / 2
		if math.abs(relative.X) <= half.X
			and math.abs(relative.Y) <= half.Y
			and math.abs(relative.Z) <= half.Z
		then
			return zone.def.id
		end
	end
	return nil
end

local function setPlayerZone(player, zoneId)
	local previous = playerZones[player]
	if previous == zoneId then
		return
	end
	playerZones[player] = zoneId
	remotes.HubZoneChanged:FireClient(player, zoneId)

	if zoneId == "HallOfFame" then
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	end
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubData = HubWorldBuilder.build()
	updateLeaderboardBoard()
end

function HubWorldManager.spawnInHub(player)
	playerInArena[player] = false
	teleportCharacter(player, HubConfig.HUB_SPAWN)
	setPlayerZone(player, nil)
end

function HubWorldManager.enterArena(player)
	if playerInArena[player] then
		return
	end
	playerInArena[player] = true
	local arenaPosition = HubConfig.ORIGIN + HubConfig.ARENA_SPAWN_OFFSET
	teleportCharacter(player, arenaPosition)
	setPlayerZone(player, nil)
end

function HubWorldManager.returnToHub(player)
	playerInArena[player] = false
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.isInArena(player)
	return playerInArena[player] == true
end

function HubWorldManager.refreshLobby(player)
	if playerZones[player] == "HallOfFame" and not playerInArena[player] then
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	end
	updateLeaderboardBoard()
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if not playerInArena[player] then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	playerInArena[player] = nil
end

function HubWorldManager.startZoneTracking()
	RunService.Heartbeat:Connect(function(dt)
		zoneCheckAccumulator += dt
		if zoneCheckAccumulator < HubConfig.ZONE_CHECK_INTERVAL then
			return
		end
		zoneCheckAccumulator = 0

		for _, player in Players:GetPlayers() do
			if playerInArena[player] then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				setPlayerZone(player, getZoneAtPosition(root.Position))
			end
		end
	end)
end

function HubWorldManager.connectRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	for _, zone in hubData.zones do
		zone.prompt.Triggered:Connect(function(player)
			local action = zone.prompt:GetAttribute("ZoneAction")
			if action == "enterArena" then
				HubWorldManager.enterArena(player)
			elseif action == "openBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif action == "showStats" then
				setPlayerZone(player, zone.def.id)
			end
		end)
	end
end

return HubWorldManager
