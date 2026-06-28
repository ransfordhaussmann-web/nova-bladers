local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local zoneParts
local playerZones = {}
local lobbyPayloads = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	local rank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		rankPoints = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
	}
end

local function refreshLobbyPayload(player)
	local payload = buildLobbyPayload(player)
	lobbyPayloads[player] = payload
	LeaderboardManager.submit(player, payload.rankPoints)
	return payload
end

local function detectZone(character)
	if not zoneParts then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local pos = root.Position
	local bestZone
	local bestDist = math.huge

	for zoneId, part in zoneParts do
		local localPos = part.CFrame:PointToObjectSpace(pos)
		local half = part.Size / 2
		if math.abs(localPos.X) <= half.X
			and math.abs(localPos.Y) <= half.Y
			and math.abs(localPos.Z) <= half.Z
		then
			local dist = localPos.Magnitude
			if dist < bestDist then
				bestDist = dist
				bestZone = zoneId
			end
		end
	end

	return bestZone
end

local function setPlayerZone(player, zoneId)
	if playerZones[player] == zoneId then
		return
	end

	playerZones[player] = zoneId
	remotes.HubZoneChanged:FireClient(player, zoneId)

	if zoneId == "HallOfFame" then
		local payload = refreshLobbyPayload(player)
		remotes.LobbyReady:FireClient(player, payload)
	end
end

function HubWorldManager.init(remotesFolder)
	remotes = remotesFolder
	_, zoneParts = HubWorldBuilder.build(HubConfig.ORIGIN)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		playerZones[player] = nil
		lobbyPayloads[player] = nil

		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if playerZones[player] == nil then
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		lobbyPayloads[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < HubConfig.ZONE_CHECK_INTERVAL then
			return
		end
		elapsed = 0

		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				setPlayerZone(player, detectZone(character))
			end
		end
	end)

	for _, zoneFolder in workspace.NovaHub:GetChildren() do
		if not zoneParts[zoneFolder.Name] then
			continue
		end

		local pad = zoneFolder:FindFirstChild("Pad")
		local prompt = pad and pad:FindFirstChild("ZonePrompt")
		if not prompt then
			continue
		end

		local zoneId = zoneFolder.Name
		local zone = HubConfig.ZONES[zoneId]
		if not zone then
			continue
		end

		prompt.Triggered:Connect(function(player)
			if zone.action == "EnterArena" then
				HubWorldManager.enterArena(player)
			elseif zone.action == "OpenBeySelect" then
				remotes.OpenBeySelect:FireClient(player)
			elseif zone.action == "OpenLobby" then
				local payload = refreshLobbyPayload(player)
				remotes.LobbyReady:FireClient(player, payload)
			end
		end)
	end
end

function HubWorldManager.enterArena(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local target = HubConfig.ORIGIN + HubConfig.ARENA_SPAWN_OFFSET
	root.CFrame = CFrame.new(target)
	playerZones[player] = nil
	remotes.HubZoneChanged:FireClient(player, nil)
end

function HubWorldManager.returnToHub(player)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local spawnPos = HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET
	root.CFrame = CFrame.new(spawnPos)
	playerZones[player] = nil
	remotes.HubZoneChanged:FireClient(player, nil)
end

function HubWorldManager.getLobbyPayload(player)
	return lobbyPayloads[player] or refreshLobbyPayload(player)
end

return HubWorldManager
