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
local playersInHub = {}
local playerZones = {}
local lastZoneCheck = 0

local function getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn")
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
	return CFrame.new(0, 5, 0)
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	}
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function findZoneAt(position)
	for _, zone in HubConfig.ZONES do
		local rel = position - zone.position
		if math.abs(rel.X) <= zone.size.X / 2
			and math.abs(rel.Y) <= zone.size.Y / 2
			and math.abs(rel.Z) <= zone.size.Z / 2
		then
			return zone
		end
	end
	return nil
end

local function sendZoneHint(player, zone)
	local zoneId = zone and zone.id or nil
	if playerZones[player] == zoneId then return end
	playerZones[player] = zoneId

	if zone and zone.id == "hallOfFame" then
		refreshLeaderboardBoard()
	end

	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		zoneName = zone and zone.name or nil,
		hint = zone and zone.hint or nil,
		action = zone and zone.action or nil,
	})
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.updateLeaderboardBoard(entries)
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	playerZones[player] = nil
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	sendZoneHint(player, nil)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.leaveHub(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, { zoneId = nil })
end

local function handleZoneAction(player, action)
	if not playersInHub[player] then return end

	if action == "enterArena" then
		HubWorldManager.leaveHub(player)
		teleportCharacter(player, getArenaSpawnCFrame())
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "viewLeaderboard" then
		refreshLeaderboardBoard()
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if playersInHub[player] ~= false then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	PlayerDataManager.save(player)
end

local function pollZones()
	local now = tick()
	if now - lastZoneCheck < HubConfig.ZONE_CHECK_INTERVAL then return end
	lastZoneCheck = now

	for player in playersInHub do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			sendZoneHint(player, findZoneAt(root.Position))
		end
	end
end

function HubWorldManager.init()
	RemotesSetup.ensure(NovaBladers)
	remotes = NovaBladers.Remotes

	HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			HubWorldManager.leaveHub(player)
			teleportCharacter(player, getArenaSpawnCFrame())
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		handleZoneAction(player, action)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(pollZones)

	task.spawn(function()
		while true do
			task.wait(HubConfig.LEADERBOARD_REFRESH)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
