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

local remotes
local hub
local playerZones = {}
local inArena = {}

local function getCharacterRoot(player)
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_PATHS do
		local current = workspace
		local valid = true
		for _, name in path do
			current = current:FindFirstChild(name)
			if not current then
				valid = false
				break
			end
		end
		if valid and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function zoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local min = zone.position - half
		local max = zone.position + half
		if position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y
			and position.Z >= min.Z and position.Z <= max.Z then
			return zone
		end
	end
	return nil
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = not inArena[player],
	})
end

function HubWorldManager.teleportToHub(player)
	local root = getCharacterRoot(player)
	if not root then return end
	root.CFrame = HubConfig.SPAWN_CFRAME + Vector3.new(0, 3, 0)
	inArena[player] = false
	playerZones[player] = nil
	sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	local root = getCharacterRoot(player)
	if not root then return end

	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 6, 0)
	end

	inArena[player] = true
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, { zoneId = nil })
end

local function handleZoneAction(player, zoneId)
	if inArena[player] then return end

	local zone
	for _, entry in HubConfig.ZONES do
		if entry.id == zoneId then
			zone = entry
			break
		end
	end
	if not zone then return end

	if zone.action == "enter_arena" then
		teleportToArena(player)
	elseif zone.action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "view_leaderboard" then
		sendLobbyReady(player)
	end
end

local function pollZones()
	for _, player in Players:GetPlayers() do
		if inArena[player] then continue end

		local root = getCharacterRoot(player)
		if not root then continue end

		local zone = zoneAtPosition(root.Position)
		local previous = playerZones[player]
		local currentId = zone and zone.id or nil

		if currentId ~= previous then
			playerZones[player] = currentId
			if zone then
				remotes.HubZoneHint:FireClient(player, {
					zoneId = zone.id,
					zoneName = zone.name,
					hint = zone.hint,
					action = zone.action,
				})
			else
				remotes.HubZoneHint:FireClient(player, { zoneId = nil })
			end
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.getRemotes()
	hub = HubWorldBuilder.build(HubConfig)

	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.updateLeaderboard(hub, leaderboard)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inArena[player] then return end
		teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		handleZoneAction(player, zoneId)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < HubConfig.ZONE_CHECK_INTERVAL then return end
		elapsed = 0
		pollZones()
	end)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if not inArena[player] then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	inArena[player] = nil
end

function HubWorldManager.refreshLeaderboard()
	if not hub then return end
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.updateLeaderboard(hub, leaderboard)
end

return HubWorldManager
