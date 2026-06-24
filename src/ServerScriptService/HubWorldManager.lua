local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local zonePads = {}
local leaderboardBoard
local playerZones = {}

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
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_BOARD.topCount),
		inHub = true,
	}
end

local function refreshLeaderboard()
	if not leaderboardBoard then return end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_BOARD.topCount)
	HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, entries)
end

local function getZoneAtPosition(position)
	for zoneId, pad in zonePads do
		local rel = pad.CFrame:PointToObjectSpace(position)
		local half = pad.Size * 0.5
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 4 and math.abs(rel.Z) <= half.Z then
			return zoneId
		end
	end
	return nil
end

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function sendZoneHint(player, zoneId)
	local zone = zoneId and getZoneConfig(zoneId)
	if zone then
		remotes.HubZoneHint:FireClient(player, {
			zoneId = zone.id,
			name = zone.name,
			hint = zone.hint,
			action = zone.action,
		})
	else
		remotes.HubZoneHint:FireClient(player, nil)
	end
end

local function updatePlayerZone(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zoneId = getZoneAtPosition(root.Position)
	if playerZones[player] ~= zoneId then
		playerZones[player] = zoneId
		sendZoneHint(player, zoneId)
	end
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	playerZones[player] = nil
	sendZoneHint(player, nil)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end
	local bowl = arena:FindFirstChild("Bowl")
	if not bowl then return nil end
	return bowl:FindFirstChild("Spawn")
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if spawn and spawn:IsA("BasePart") then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 10, 0)
	end

	playerZones[player] = nil
	remotes.HubZoneHint:FireClient(player, nil)
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder, zonePads = HubWorldBuilder.build()
	leaderboardBoard = HubWorldBuilder.createLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		remotes.OpenBeySelect:FireClient(player, true)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "enterArena" then
			if playerZones[player] == "arena" then
				teleportToArena(player)
			end
		elseif action == "openBeySelect" then
			if playerZones[player] == "beyLab" then
				remotes.OpenBeySelect:FireClient(player, true)
			end
		end
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.defer(function()
				teleportToHub(player)
			end)
		end)

		if player.Character then
			teleportToHub(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				updatePlayerZone(player)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			refreshLeaderboard()
		end
	end)
end

return HubWorldManager
