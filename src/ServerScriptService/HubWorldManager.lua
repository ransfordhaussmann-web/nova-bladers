local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local hub
local remotes
local playerDataManager
local leaderboardManager
local zoneConnections = {}

local function getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if not arena then return nil end
	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return arena:FindFirstChildWhichIsA("SpawnLocation", true)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe + Vector3.new(0, 3, 0)
	end
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
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(5)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function refreshLeaderboardBoard()
	if not hub then return end
	HubWorldBuilder.updateLeaderboard(hub, leaderboardManager.getTop(5))
end

local function onZoneEnter(player, zoneId)
	local zone
	for _, z in HubConfig.ZONES do
		if z.id == zoneId then
			zone = z
			break
		end
	end
	if not zone then return end

	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zone.name,
		hint = zone.hint,
	})

	if zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	end
end

local function bindZoneTriggers()
	for _, conn in zoneConnections do
		conn:Disconnect()
	end
	table.clear(zoneConnections)

	if not hub then return end

	for _, zoneConfig in HubConfig.ZONES do
		local zoneFolder = hub:FindFirstChild(zoneConfig.id)
		local zonePart = zoneFolder and zoneFolder:FindFirstChild("Zone")
		local trigger = zonePart and zonePart:FindFirstChild("Trigger")
		if trigger then
			local debounce = {}
			local conn = trigger.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				if not character then return end
				local player = Players:GetPlayerFromCharacter(character)
				if not player or debounce[player] then return end
				debounce[player] = true
				task.delay(2, function()
					debounce[player] = nil
				end)
				onZoneEnter(player, zoneConfig.id)
			end)
			table.insert(zoneConnections, conn)
		end
	end
end

function HubWorldManager.enterArena(player)
	local spawn = getArenaSpawn()
	if spawn then
		teleportCharacter(player, spawn.CFrame)
	else
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Fallback-Position")
		teleportCharacter(player, CFrame.new(0, 10, 0))
	end
end

function HubWorldManager.returnToHub(player)
	if not hub then return end
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn then
		teleportCharacter(player, spawn.CFrame)
	end
	sendLobbyReady(player, true)
end

function HubWorldManager.onPlayerReady(player)
	playerDataManager.load(player)
	local data = playerDataManager.get(player)
	leaderboardManager.submit(player, playerDataManager.getRankPoints(data))
	refreshLeaderboardBoard()
	sendLobbyReady(player, true)
end

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager

	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build(HubConfig)
	bindZoneTriggers()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				HubWorldManager.returnToHub(player)
			end)
		end)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerReady(player)
	end
end

return HubWorldManager
