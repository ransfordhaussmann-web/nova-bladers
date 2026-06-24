local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local hub
local playerZones = {}
local zoneParts = {}

local function resolvePath(path)
	local current = game
	for segment in string.split(path, ".") do
		if segment == "Workspace" then
			current = workspace
		else
			current = current:FindFirstChild(segment)
			if not current then return nil end
		end
	end
	return current
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local spawn = resolvePath(path)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return nil
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player, inHub)
	local PlayerDataManager = require(script.Parent.PlayerDataManager)
	local LeaderboardManager = require(script.Parent.LeaderboardManager)

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

local function refreshLeaderboardBoard()
	if not hub then return end
	local LeaderboardManager = require(script.Parent.LeaderboardManager)
	HubWorldBuilder.updateLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN, HubConfig.SPAWN_LOOK)
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 10, 0)
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Fallback-Position genutzt")
	end
end

local function sendZoneHint(player, zonePart)
	if not zonePart then
		remotes.HubZoneHint:FireClient(player, nil)
		return
	end
	remotes.HubZoneHint:FireClient(player, {
		id = zonePart:GetAttribute("ZoneId"),
		label = zonePart:GetAttribute("ZoneLabel"),
		hint = zonePart:GetAttribute("ZoneHint"),
		action = zonePart:GetAttribute("ZoneAction"),
	})
end

local function pointInsidePart(point, part)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function detectZone(player)
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	for _, part in zoneParts do
		if pointInsidePart(root.Position, part) then
			return part
		end
	end
	return nil
end

local function updatePlayerZone(player)
	local zone = detectZone(player)
	local previous = playerZones[player]
	if zone == previous then return end

	playerZones[player] = zone
	sendZoneHint(player, zone)
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function handleZoneAction(player, action)
	if action == "enterArena" then
		teleportToArena(player)
		sendLobbyReady(player, false)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "viewLeaderboard" then
		refreshLeaderboardBoard()
		sendZoneHint(player, playerZones[player])
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player, true)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.init(deps)
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()
	zoneParts = HubWorldBuilder.getZoneParts(hub)
	refreshLeaderboardBoard()

	local PlayerDataManager = deps and deps.PlayerDataManager
	local LeaderboardManager = deps and deps.LeaderboardManager

	Players.PlayerAdded:Connect(function(player)
		if PlayerDataManager then
			PlayerDataManager.load(player)
		end

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			teleportToHub(player)
			sendLobbyReady(player, true)
			if PlayerDataManager and LeaderboardManager then
				local data = PlayerDataManager.get(player)
				LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
			end
			refreshLeaderboardBoard()
		end)
	end)

	for _, player in Players:GetPlayers() do
		if PlayerDataManager then
			PlayerDataManager.load(player)
		end
		if player.Character then
			teleportToHub(player)
			sendLobbyReady(player, true)
		end
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
		sendLobbyReady(player, false)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "string" then return end
		local zone = playerZones[player]
		if not zone or zone:GetAttribute("ZoneAction") ~= action then return end
		handleZoneAction(player, action)
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				updatePlayerZone(player)
			end
			task.wait(0.25)
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
