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
local hubFolder
local playersInHub = {}
local playerZones = {}
local zoneParts = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if arena then
		for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(spawnName)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end

		local bowl = arena:FindFirstChild("Bowl", true)
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + HubConfig.ARENA_FALLBACK_OFFSET
		end
	end

	return HubWorldBuilder.getHubSpawnCFrame() + Vector3.new(0, 20, -80)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame
end

local function collectZoneParts()
	table.clear(zoneParts)
	if not hubFolder then return end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return end

	for _, zoneFolder in zones:GetChildren() do
		local pad = zoneFolder:FindFirstChild("Pad")
		if pad then
			table.insert(zoneParts, {
				id = pad:GetAttribute("ZoneId"),
				action = pad:GetAttribute("ZoneAction"),
				position = pad.Position,
				config = HubConfig.ZONES[pad:GetAttribute("ZoneId")],
			})
		end
	end
end

local function getNearestZone(position)
	local nearest
	local nearestDist = HubConfig.ZONE_DETECT_RADIUS

	for _, zone in zoneParts do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function refreshLeaderboardBoard()
	if not hubFolder then return end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD.topCount)
	local boardFolder = hubFolder:FindFirstChild("LeaderboardBoard")
	local board = boardFolder and boardFolder:FindFirstChild("Board")
	if board then
		HubWorldBuilder.updateLeaderboardBoard(board, entries)
	end
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = playersInHub[player] == true,
	})
end

function HubWorldManager.isPlayerInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.teleportToHub(player)
	playersInHub[player] = true
	playerZones[player] = nil
	teleportCharacter(player, HubWorldBuilder.getHubSpawnCFrame())
	sendLobbyReady(player)
	remotes.HubZoneHint:FireClient(player, nil)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.teleportToArena(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	teleportCharacter(player, findArenaSpawnCFrame())
	remotes.HubZoneHint:FireClient(player, nil)
end

local function handleZoneAction(player, zoneId)
	if not playersInHub[player] then return end

	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enterArena" then
		HubWorldManager.teleportToArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	end
end

local function onCharacterAdded(player, character)
	if playersInHub[player] then
		task.defer(function()
			teleportCharacter(player, HubWorldBuilder.getHubSpawnCFrame())
		end)
	end
end

local function trackZones()
	for _, player in Players:GetPlayers() do
		if not playersInHub[player] then continue end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local nearest = getNearestZone(root.Position)
		local currentZone = playerZones[player]

		if nearest then
			if currentZone ~= nearest.id then
				playerZones[player] = nearest.id
				local zoneConfig = nearest.config
				remotes.HubZoneHint:FireClient(player, {
					zoneId = nearest.id,
					name = zoneConfig and zoneConfig.name or nearest.id,
					hint = zoneConfig and zoneConfig.hint or "",
					action = nearest.action,
				})
			end
		elseif currentZone then
			playerZones[player] = nil
			remotes.HubZoneHint:FireClient(player, nil)
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	collectZoneParts()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			HubWorldManager.teleportToArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		playersInHub[player] = true
		playerZones[player] = nil

		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)

		if player.Character then
			onCharacterAdded(player, player.Character)
		end

		task.defer(function()
			sendLobbyReady(player)
			refreshLeaderboardBoard()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local data = PlayerDataManager.get(player)
		if data then
			LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
			PlayerDataManager.persist(player)
		end
		playersInHub[player] = nil
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	RunService.Heartbeat:Connect(trackZones)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerDataManager.persist(player)
		end
	end)
end

return HubWorldManager
