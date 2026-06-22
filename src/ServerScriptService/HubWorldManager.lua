local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local zoneParts = {}
local playerZones = {}
local playersInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player, inHub)
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
		inHub = inHub,
	}
end

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena") or workspace:FindFirstChild("Bowl")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
			or arena:FindFirstChild("SpawnPoint", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 5, 90)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function isInsideZone(position, zone)
	local rel = position - zone.position
	local half = zone.size / 2
	return math.abs(rel.X) <= half.X
		and math.abs(rel.Y) <= half.Y + 4
		and math.abs(rel.Z) <= half.Z
end

local function detectZoneForPlayer(player)
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	for _, zone in HubConfig.ZONES do
		if isInsideZone(root.Position, zone) then
			return zone
		end
	end
	return nil
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	local hub = workspace:FindFirstChild("NovaHub")
	if hub then
		HubWorldBuilder.buildLeaderboardBoard(hub, entries)
	end
end

function HubWorldManager.sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	player:SetAttribute("InHub", true)
	player:SetAttribute("InMatch", false)
	teleportCharacter(player, HubConfig.SPAWN_CFRAME)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	player:SetAttribute("InHub", true)
	player:SetAttribute("InMatch", false)
	teleportCharacter(player, HubConfig.SPAWN_CFRAME)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = false
	player:SetAttribute("InHub", false)
	player:SetAttribute("InMatch", true)
	teleportCharacter(player, getArenaSpawnCFrame())
	HubWorldManager.sendLobbyReady(player, false)
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone or not playersInHub[player] then
		return
	end

	if zone.action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "openBeySelect" then
		HubWorldManager.openBeySelect(player)
	end
end

local function updatePlayerZone(player)
	if not playersInHub[player] then
		return
	end

	local zone = detectZoneForPlayer(player)
	local previous = playerZones[player]

	if zone then
		if not previous or previous.id ~= zone.id then
			playerZones[player] = zone
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zone.id,
				name = zone.name,
				hint = zone.hint,
				action = zone.action,
			})
		end
	elseif previous then
		playerZones[player] = nil
		remotes.HubZoneHint:FireClient(player, nil)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local _, builtZones = HubWorldBuilder.build()
	zoneParts = builtZones
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			HubWorldManager.enterArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			HubWorldManager.handleZoneAction(player, zoneId)
		end
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				updatePlayerZone(player)
			end
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			refreshLeaderboardBoard()
		end
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	local function onCharacter()
		task.defer(function()
			if player:GetAttribute("InMatch") then
				teleportCharacter(player, getArenaSpawnCFrame())
			elseif player:GetAttribute("InHub") ~= false then
				HubWorldManager.spawnInHub(player)
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	PlayerDataManager.save(player)
end

return HubWorldManager
