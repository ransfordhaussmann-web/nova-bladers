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
local inArena = {}

local function resolveArenaSpawn()
	local node = game:GetService("Workspace")
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("BasePart") then
		return node.CFrame + Vector3.new(0, 3, 0)
	end
	if node and node:IsA("SpawnLocation") then
		return node.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.ARENA_SPAWN_FALLBACK)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
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

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyState(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
	HubWorldManager.sendLobbyState(player)
end

local function enterArena(player)
	inArena[player] = true
	teleportPlayer(player, resolveArenaSpawn())
	remotes.LobbyReady:FireClient(player, { inHub = false })
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function showStats(player)
	HubWorldManager.sendLobbyState(player)
	remotes.HubZoneAction:FireClient(player, {
		action = "ShowStats",
		payload = buildLobbyPayload(player),
	})
end

local function getNearestZone(position)
	local nearest, nearestDist = nil, HubConfig.ZONE_RADIUS
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end
	return nearest
end

local function pollZones()
	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local zone = getNearestZone(root.Position)
				local previous = playerZones[player]
				if zone ~= previous then
					playerZones[player] = zone
					if zone then
						remotes.HubZoneHint:FireClient(player, {
							zoneId = zone.id,
							name = zone.name,
							hint = zone.hint,
							actionLabel = zone.actionLabel,
							action = zone.action,
						})
					else
						remotes.HubZoneHint:FireClient(player, nil)
					end
				end
			end
		end
	end
end

local function handleZoneAction(player, action)
	if inArena[player] then return end
	if action == "EnterArena" then
		enterArena(player)
	elseif action == "OpenBeySelect" then
		openBeySelect(player)
	elseif action == "ShowStats" then
		showStats(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()

	local leaderboard = LeaderboardManager.getTop(5)
	HubWorldBuilder.build(leaderboard)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			handleZoneAction(player, action)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		playerZones[player] = nil
		inArena[player] = nil
		PlayerDataManager.load(player)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
				HubWorldManager.sendLobbyState(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		inArena[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.sendLobbyState(player)
	end

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			pollZones()
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
