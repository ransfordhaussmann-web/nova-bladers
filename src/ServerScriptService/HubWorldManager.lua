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
local leaderboardBoard
local playerZones = {}
local zoneDebounce = {}

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	local bowl = arena and arena:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn")
			or bowl:FindFirstChild("SpawnLocation")
			or bowl:FindFirstChildWhichIsA("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return HubConfig.ARENA_FALLBACK
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function refreshLeaderboardBoard()
	if not leaderboardBoard then return end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboard(leaderboardBoard, entries)
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local leaderboard = LeaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		inHub = true,
	})
end

local function clearZoneHint(player)
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
end

local function setPlayerZone(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		clearZoneHint(player)
		return
	end
	playerZones[player] = zoneId
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zone.id,
		name = zone.name,
		hint = zone.hint,
		action = zone.action,
	})
end

local function onZoneTouched(zonePart, hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local zoneId = zonePart:GetAttribute("ZoneId")
	if not zoneId then return end

	local key = player.UserId .. "_" .. zoneId
	if zoneDebounce[key] then return end
	zoneDebounce[key] = true
	task.delay(0.35, function()
		zoneDebounce[key] = nil
	end)

	setPlayerZone(player, zoneId)
end

local function onZoneTouchEnded(zonePart, hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local zoneId = zonePart:GetAttribute("ZoneId")
	if playerZones[player] == zoneId then
		clearZoneHint(player)
	end
end

function HubWorldManager.teleportToArena(player)
	teleportCharacter(player, getArenaSpawnCFrame())
	clearZoneHint(player)
end

function HubWorldManager.returnToHub(player)
	teleportCharacter(player, HubConfig.SPAWN)
	sendLobbyReady(player)
end

local function handleZoneAction(player, zoneId)
	local activeZone = playerZones[player]
	if activeZone ~= zoneId then return end

	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "EnterArena" then
		HubWorldManager.teleportToArena(player)
	elseif zone.action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "ViewLeaderboard" then
		refreshLeaderboardBoard()
		local entries = LeaderboardManager.getTop(5)
		remotes.LobbyReady:FireClient(player, {
			wins = PlayerDataManager.get(player).Wins,
			losses = PlayerDataManager.get(player).Losses,
			rank = PlayerDataManager.getRankPoints(PlayerDataManager.get(player)),
			modeLabel = getModeLabel(#Players:GetPlayers()),
			leaderboard = entries,
			inHub = true,
		})
	end
end

local function connectZone(zonePart)
	zonePart.Touched:Connect(function(hit)
		onZoneTouched(zonePart, hit)
	end)
	zonePart.TouchEnded:Connect(function(hit)
		onZoneTouchEnded(zonePart, hit)
	end)
end

local function onCharacterAdded(player)
	task.defer(function()
		HubWorldManager.returnToHub(player)
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel, leaderboardBoard = HubWorldBuilder.build()

	local zonesFolder = hubModel:FindFirstChild("Zones")
	if zonesFolder then
		for _, zonePart in zonesFolder:GetChildren() do
			if zonePart:IsA("BasePart") then
				connectZone(zonePart)
			end
		end
	end

	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
