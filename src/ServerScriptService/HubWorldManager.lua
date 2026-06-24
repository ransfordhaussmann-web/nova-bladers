local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerZones = {}
local inArena = {}

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
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("BasePart") then
		return node
	end
	return nil
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(position)
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = not inArena[player],
	})
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(entries)
end

local function getNearestZone(position)
	local nearest
	local nearestDist = HubConfig.ZONE_PROXIMITY

	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function updatePlayerZone(player)
	if inArena[player] then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zone = getNearestZone(root.Position)
	local previous = playerZones[player]

	if zone then
		playerZones[player] = zone.id
		if not previous or previous ~= zone.id then
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zone.id,
				name = zone.name,
				hint = zone.hint,
				active = true,
			})
		end
	else
		playerZones[player] = nil
		if previous then
			remotes.HubZoneHint:FireClient(player, { active = false })
		end
	end
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	playerZones[player] = nil
	teleportCharacter(player, HubConfig.SPAWN_POSITION)
	sendLobbyReady(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena spawn not found — add Workspace.Arena.Bowl.Spawn")
		return
	end

	inArena[player] = true
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, { active = false })
	teleportCharacter(player, spawn.Position + Vector3.new(0, 3, 0))
	remotes.EnterArena:FireClient(player)
end

local function onZoneAction(player, zoneId)
	if inArena[player] then return end

	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			if zone.action == "enterArena" then
				HubWorldManager.enterArena(player)
			elseif zone.action == "openBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif zone.action == "viewLeaderboard" then
				sendLobbyReady(player)
			end
			return
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not inArena[player] then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end

	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	inArena[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			onZoneAction(player, zoneId)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				updatePlayerZone(player)
			end
		end
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
