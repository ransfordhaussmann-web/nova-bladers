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

local function flatDistance(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getHubCenter()
	local floorY = HubConfig.SPAWN_POSITION.Y - 3.5
	return Vector3.new(HubConfig.SPAWN_POSITION.X, floorY, HubConfig.SPAWN_POSITION.Z + 7)
end

local function getZoneAtPosition(position)
	local center = getHubCenter()
	local bestId, bestZone, bestDist = nil, nil, math.huge

	for _, zone in HubConfig.ZONES do
		local zonePos = center + zone.position
		local radius = math.max(zone.size.X, zone.size.Z) / 2
		local dist = flatDistance(position, zonePos)
		if dist <= radius and dist < bestDist then
			bestId = zone.id
			bestZone = zone
			bestDist = dist
		end
	end

	return bestId, bestZone
end

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

local function buildModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.getLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = buildModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, HubWorldManager.getLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	hrp.CFrame = CFrame.new(HubConfig.SPAWN_POSITION, HubConfig.SPAWN_POSITION + HubConfig.SPAWN_LOOK)
	playerZones[player] = nil
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = getArenaSpawnCFrame()
	playerZones[player] = nil
end

local function enterArena(player)
	HubWorldManager.teleportToArena(player)
end

function HubWorldManager.refreshLeaderboardBoard()
	HubWorldBuilder.updateLeaderboardBoard(LeaderboardManager.getTop(5))
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if zoneId == "ArenaGate" then
		enterArena(player)
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.refreshLeaderboardBoard()
	end
end

function HubWorldManager.updatePlayerZone(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local zoneId, zone = getZoneAtPosition(hrp.Position)
	local prev = playerZones[player]

	if zoneId ~= prev then
		playerZones[player] = zoneId
		if zone then
			remotes.HubZoneHint:FireClient(player, {
				zoneId = zoneId,
				name = zone.name,
				hint = zone.hint,
				actionLabel = zone.actionLabel,
			})
		else
			remotes.HubZoneHint:FireClient(player, nil)
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(enterArena)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		if not HubConfig.ZONES[zoneId] then return end

		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local currentId = getZoneAtPosition(hrp.Position)
		if currentId ~= zoneId then return end

		HubWorldManager.handleZoneAction(player, zoneId)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			HubWorldManager.spawnInHub(player)
			HubWorldManager.sendLobbyReady(player)
		end)

		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
		HubWorldManager.sendLobbyReady(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				HubWorldManager.updatePlayerZone(player)
			end
			task.wait(0.35)
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
