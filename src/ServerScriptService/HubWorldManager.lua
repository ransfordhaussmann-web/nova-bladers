local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local hub
local zoneTriggers = {}
local playerZones = {}
local remotes

local PlayerDataManager
local LeaderboardManager

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
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawnPart = hub and hub:FindFirstChild("HubSpawn")
	local pos = spawnPart and spawnPart.Position or HubConfig.SPAWN_OFFSET
	root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
end

local function teleportToArena(player)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawn = findArenaSpawn()
	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		warn("[HubWorldManager] Kein Arena-Spawn gefunden — nutze Hub-Mitte als Fallback")
		root.CFrame = CFrame.new(0, 5, 0)
	end
end

local function getPlayerZone(player)
	local character = player.Character
	if not character then return nil end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local pos = root.Position
	for zoneId, trigger in zoneTriggers do
		local rel = trigger.CFrame:PointToObjectSpace(pos)
		local half = trigger.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
			return zoneId
		end
	end
	return nil
end

local function sendLobbyReady(player)
	if not PlayerDataManager or not LeaderboardManager then return end

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = true,
	})
end

local function sendZoneHint(player, zoneId)
	local zoneDef = HubConfig.ZONES[zoneId]
	if not zoneDef then return end

	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zoneDef.name,
		hint = zoneDef.hint,
		action = zoneDef.action,
	})
end

local function clearZoneHint(player)
	remotes.HubZoneHint:FireClient(player, {
		zoneId = nil,
	})
end

local function onZoneChanged(player, newZone)
	local prev = playerZones[player]
	if prev == newZone then return end
	playerZones[player] = newZone

	if newZone then
		sendZoneHint(player, newZone)
	else
		clearZoneHint(player)
	end
end

local function refreshLeaderboardBoard()
	if not LeaderboardManager or not hub then return end
	HubWorldBuilder.updateLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player)
end

function HubWorldManager.init(deps)
	PlayerDataManager = deps.PlayerDataManager
	LeaderboardManager = deps.LeaderboardManager

	remotes = RemotesSetup.ensure()
	hub, zoneTriggers = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
		remotes.LobbyReady:FireClient(player, { inHub = false })
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		local zone = playerZones[player]
		if zone == "BeyLab" then
			remotes.OpenBeySelect:FireClient(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character then
			teleportToHub(player)
			sendLobbyReady(player)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			teleportToHub(player)
			sendLobbyReady(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				onZoneChanged(player, getPlayerZone(player))
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
