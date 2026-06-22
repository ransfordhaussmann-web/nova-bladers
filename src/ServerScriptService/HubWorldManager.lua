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
local playerZones = {}
local playerInArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = options.inHub == true,
		inArena = options.inArena == true,
	}
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function getNearestZone(position)
	local nearestZone
	local nearestDistance = HubConfig.ZONE_ENTER_RADIUS

	for _, zone in HubConfig.ZONES do
		local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if distance <= nearestDistance then
			nearestDistance = distance
			nearestZone = zone
		end
	end

	return nearestZone
end

function HubWorldManager.spawnInHub(player)
	playerInArena[player] = false
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, { inHub = true }))
end

function HubWorldManager.returnToHub(player)
	playerInArena[player] = false
	playerZones[player] = nil
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	if playerInArena[player] then
		return
	end

	playerInArena[player] = true
	playerZones[player] = nil

	local arenaCFrame = HubWorldBuilder.findArenaSpawn()
	teleportCharacter(player, arenaCFrame)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, { inArena = true }))
end

function HubWorldManager.refreshLeaderboardBoard()
	local hub = workspace:FindFirstChild(HubConfig.WORLD_NAME)
	if not hub then
		return
	end

	local oldBoard = hub:FindFirstChild("LeaderboardBoard")
	if oldBoard then
		oldBoard:Destroy()
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playerInArena[player] then
			teleportCharacter(player, HubWorldBuilder.findArenaSpawn())
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, { inArena = true }))
		else
			HubWorldManager.spawnInHub(player)
		end
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	playerInArena[player] = nil
end

function HubWorldManager.startZoneLoop()
	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)

			for _, player in Players:GetPlayers() do
				if playerInArena[player] then
					continue
				end

				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root then
					continue
				end

				local zone = getNearestZone(root.Position)
				local previous = playerZones[player]

				if zone and zone.id ~= previous then
					playerZones[player] = zone.id
					remotes.HubZoneHint:FireClient(player, {
						zoneId = zone.id,
						name = zone.name,
						hint = zone.hint,
						action = zone.action,
					})
				elseif not zone and previous then
					playerZones[player] = nil
					remotes.HubZoneHint:FireClient(player, { clear = true })
				end
			end
		end
	end)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local leaderboard = LeaderboardManager.getTop(5)
	HubWorldBuilder.build(leaderboard)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if playerInArena[player] then
			return
		end
		remotes.OpenBeySelect:FireClient(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if playerInArena[player] then
			return
		end

		if action == "enterArena" then
			HubWorldManager.enterArena(player)
		elseif action == "openBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "showLeaderboard" then
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, { inHub = true, showStats = true }))
		end
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	HubWorldManager.startZoneLoop()

	local lighting = game:GetService("Lighting")
	lighting.Ambient = HubConfig.AMBIENT
	lighting.OutdoorAmbient = HubConfig.AMBIENT
	lighting.Brightness = HubConfig.OUTDOOR_BRIGHTNESS
end

return HubWorldManager
