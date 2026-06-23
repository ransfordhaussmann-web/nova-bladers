local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerZones = {}
local playerInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function resolveArenaSpawn()
	local current = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		current = current and current:FindFirstChild(name)
	end
	if current and current:IsA("BasePart") then
		return current
	end
	return nil
end

local function getPlayerRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(player, position)
	local root = getPlayerRoot(player)
	if not root then
		return false
	end
	root.CFrame = CFrame.new(position)
	return true
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

local function refreshLeaderboardBoard()
	local hub = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if not hub then
		return
	end
	HubWorldBuilder.createLeaderboardBoard(hub, LeaderboardManager.getTop(HubConfig.LEADERBOARD_BOARD.topCount))
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function detectZone(position)
	for _, zone in HubConfig.ZONES do
		local flat = Vector3.new(position.X, zone.position.Y, position.Z)
		if (flat - zone.position).Magnitude <= HubConfig.ZONE_RADIUS then
			return zone
		end
	end
	return nil
end

local function updatePlayerZone(player)
	local root = getPlayerRoot(player)
	if not root then
		return
	end

	local zone = detectZone(root.Position)
	local previous = playerZones[player]

	if zone then
		playerZones[player] = zone.id
		if not previous or previous ~= zone.id then
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zone.id,
				label = zone.label,
				hint = zone.hint,
				action = zone.action,
			})
		end
	else
		playerZones[player] = nil
		if previous then
			remotes.HubZoneHint:FireClient(player, nil)
		end
	end
end

function HubWorldManager.returnToHub(player)
	playerInHub[player] = true
	playerZones[player] = nil
	teleportTo(player, HubConfig.SPAWN)
	sendLobbyReady(player, true)
	remotes.HubZoneHint:FireClient(player, nil)
end

function HubWorldManager.enterArena(player)
	playerInHub[player] = false
	local spawn = resolveArenaSpawn()
	if spawn then
		teleportTo(player, spawn.Position + Vector3.new(0, 3, 0))
	else
		warn("[NovaBladers] Arena spawn missing — erwartet Workspace.Arena.Bowl.Spawn")
		teleportTo(player, Vector3.new(0, 5, 0))
	end
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		HubWorldManager.returnToHub(player)
	end)

	if player.Character then
		task.defer(function()
			HubWorldManager.returnToHub(player)
		end)
	end
end

local function onPlayerRemoving(player)
	playerZones[player] = nil
	playerInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then
			return
		end
		if playerZones[player] ~= zoneId then
			return
		end

		local zone = HubConfig.ZONES[zoneId]
		if not zone then
			return
		end

		if zone.action == "enterArena" then
			HubWorldManager.enterArena(player)
		elseif zone.action == "openBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
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
				if playerInHub[player] then
					updatePlayerZone(player)
				end
			end
		end
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
