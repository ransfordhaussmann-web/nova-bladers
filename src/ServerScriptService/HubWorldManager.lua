local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local hubModel
local arenaPad
local arenaPrompt
local playerZones = {}
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

local function buildLobbyPayload(player, data, leaderboard)
	local PlayerDataManager = require(script.Parent.PlayerDataManager)
	local LeaderboardManager = require(script.Parent.LeaderboardManager)

	if not data then
		data = PlayerDataManager.get(player)
	end
	if not leaderboard then
		leaderboard = LeaderboardManager.getTop(5)
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = PlayerDataManager.getRankPoints(data),
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = true,
	}
end

local function sendLobbyReady(player)
	local PlayerDataManager = require(script.Parent.PlayerDataManager)
	local LeaderboardManager = require(script.Parent.LeaderboardManager)

	local data = PlayerDataManager.get(player)
	local leaderboard = LeaderboardManager.getTop(5)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, data, leaderboard))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubConfig.SPAWN_CFRAME
end

local function getZoneAtPosition(position)
	for zoneKey, zone in HubConfig.ZONES do
		local half = zone.size * 0.5
		local min = zone.center - half
		local max = zone.center + half
		if position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y
			and position.Z >= min.Z and position.Z <= max.Z
		then
			return zoneKey, zone
		end
	end
	return nil, nil
end

local function handleZoneAction(player, zone)
	if not zone or not zone.action then return end
	if not playersInHub[player] then return end

	if zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showStats" then
		local PlayerDataManager = require(script.Parent.PlayerDataManager)
		local LeaderboardManager = require(script.Parent.LeaderboardManager)
		local payload = buildLobbyPayload(player)
		payload.showPanel = true
		remotes.LobbyReady:FireClient(player, payload)
	end
end

function HubWorldManager.enterArena(player)
	if not playersInHub[player] then return end
	playersInHub[player] = nil
	playerZones[player] = nil

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = HubConfig.ARENA_TELEPORT_CFRAME
		end
	end

	remotes.LobbyReady:FireClient(player, { inHub = false })
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportToHub(player)
	sendLobbyReady(player)
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.init(workspace, playerDataManager, leaderboardManager)
	remotes = RemotesSetup.ensure()
	hubModel, arenaPad, arenaPrompt = HubWorldBuilder.build(workspace)

	arenaPrompt.Triggered:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		playerDataManager.load(player)
		playersInHub[player] = true

		player.CharacterAdded:Connect(function()
			if playersInHub[player] then
				task.defer(teleportToHub, player)
			end
		end)

		task.defer(function()
			sendLobbyReady(player)
			local data = playerDataManager.get(player)
			leaderboardManager.submit(player, playerDataManager.getRankPoints(data))
		end)
	end)

	for _, player in Players:GetPlayers() do
		playersInHub[player] = true
		task.defer(sendLobbyReady, player)
	end

	RunService.Heartbeat:Connect(function()
		for player, inHub in playersInHub do
			if not inHub then continue end
			local character = player.Character
			if not character then continue end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then continue end

			local zoneKey, zone = getZoneAtPosition(root.Position)
			if playerZones[player] ~= zoneKey then
				playerZones[player] = zoneKey
				if zone then
					remotes.HubZoneChanged:FireClient(player, {
						zoneId = zone.id,
						hint = zone.hint,
					})
					handleZoneAction(player, zone)
				else
					remotes.HubZoneChanged:FireClient(player, {
						zoneId = nil,
						hint = nil,
					})
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		playerZones[player] = nil
	end)
end

return HubWorldManager
