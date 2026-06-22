local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local Remotes
local hubFolder
local playersInHub = {}
local currentZone = {}
local zoneCheckAccum = 0

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
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = targetCFrame
	end
end

local function getHubSpawnCFrame()
	if hubFolder then
		local spawn = hubFolder:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

local function getZoneAtPosition(position)
	local bestZone
	local bestDist = HubConfig.ZONE_ACTION_RANGE

	for _, zone in HubConfig.ZONES do
		local flat = Vector3.new(position.X, zone.position.Y, position.Z)
		local zoneCenter = zone.position
		local dist = (flat - zoneCenter).Magnitude
		if dist <= bestDist then
			bestDist = dist
			bestZone = zone
		end
	end

	return bestZone
end

local function refreshLeaderboardBoard()
	if not hubFolder then
		return
	end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, entries)
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = playersInHub[player] == true,
	}
	Remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.teleportToHub(player)
	playersInHub[player] = true
	currentZone[player] = nil
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.enterArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Kein Arena-Spawn gefunden")
		return
	end

	playersInHub[player] = false
	currentZone[player] = nil
	Remotes.HubZoneHint:FireClient(player, nil)

	local target = spawn:IsA("BasePart") and spawn.CFrame or CFrame.new(spawn.Position)
	teleportCharacter(player, target + Vector3.new(0, 3, 0))

	local payload = {
		wins = PlayerDataManager.get(player).Wins,
		losses = PlayerDataManager.get(player).Losses,
		rank = PlayerDataManager.getRankPoints(PlayerDataManager.get(player)),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = false,
	}
	Remotes.LobbyReady:FireClient(player, payload)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if playersInHub[player] ~= false then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	currentZone[player] = nil
	PlayerDataManager.save(player)
end

local function onZoneAction(player, zoneId)
	if not playersInHub[player] then
		return
	end

	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		return
	end

	if zone.action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "OpenBeySelect" then
		Remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "ViewLeaderboard" then
		refreshLeaderboardBoard()
		HubWorldManager.sendLobbyReady(player)
	end
end

local function checkZones(dt)
	zoneCheckAccum += dt
	if zoneCheckAccum < 0.25 then
		return
	end
	zoneCheckAccum = 0

	for _, player in Players:GetPlayers() do
		if not playersInHub[player] then
			continue
		end

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local zone = getZoneAtPosition(hrp.Position)
		local zoneId = zone and zone.id or nil
		if zoneId ~= currentZone[player] then
			currentZone[player] = zoneId
			if zone then
				Remotes.HubZoneHint:FireClient(player, {
					id = zone.id,
					name = zone.name,
					hint = zone.hint,
					action = zone.action,
				})
			else
				Remotes.HubZoneHint:FireClient(player, nil)
			end
		end
	end
end

function HubWorldManager.init()
	Remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		onZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(checkZones)

	task.spawn(function()
		while true do
			task.wait(60)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
