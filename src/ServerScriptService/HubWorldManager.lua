local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hub
local remotes
local playersInHub = {}
local playerZones = {}
local playersInArena = {}

local function getCharacterPosition(player)
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	return root.Position
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn:IsA("BasePart") and spawn or spawn:FindFirstChildWhichIsA("BasePart")
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function teleportTo(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
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

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function refreshLeaderboardBoard()
	HubWorldBuilder.updateLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

local function getZoneAtPosition(position)
	if not position then return nil end

	local hubOrigin = hub:FindFirstChild("HubSpawn")
	local origin = hubOrigin and hubOrigin.Position - HubConfig.SPAWN_OFFSET or Vector3.zero

	for _, zone in HubConfig.ZONES do
		local zonePos = origin + zone.position
		local flat = Vector3.new(position.X - zonePos.X, 0, position.Z - zonePos.Z)
		if flat.Magnitude <= zone.radius then
			return zone
		end
	end
	return nil
end

local function setPlayerInHub(player, inHub)
	playersInHub[player] = inHub or nil
	playersInArena[player] = (not inHub) or nil
end

function HubWorldManager.spawnInHub(player)
	local spawn = hub:FindFirstChild("HubSpawn")
	if not spawn then return end

	player.CharacterAdded:Connect(function()
		if playersInArena[player] then return end
		task.wait(0.1)
		teleportTo(player, spawn.CFrame)
	end)

	if player.Character then
		teleportTo(player, spawn.CFrame)
	end

	setPlayerInHub(player, true)
	sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	setPlayerInHub(player, true)
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)

	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and player.Character then
		teleportTo(player, spawn.CFrame)
	end

	sendLobbyReady(player, true)
end

local function enterArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden")
		return
	end

	setPlayerInHub(player, false)
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
	teleportTo(player, spawn.CFrame)
	sendLobbyReady(player, false)
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end
	if not playersInHub[player] then return end

	if zone.action == "enterArena" then
		enterArena(player)
	elseif zone.action == "openBeySelect" then
		openBeySelect(player)
	elseif zone.action == "viewLeaderboard" then
		sendLobbyReady(player, true)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	HubWorldManager.spawnInHub(player)
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	playersInArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build(Vector3.zero)
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			enterArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < HubConfig.ZONE_CHECK_INTERVAL then return end
		elapsed = 0

		for player, _ in playersInHub do
			local zone = getZoneAtPosition(getCharacterPosition(player))
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
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			refreshLeaderboardBoard()
			for player, _ in playersInHub do
				local data = PlayerDataManager.get(player)
				LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
			end
		end
	end)
end

return HubWorldManager
