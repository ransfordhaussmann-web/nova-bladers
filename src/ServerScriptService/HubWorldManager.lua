local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playerZones = {}
local inArena = {}

local function getArenaSpawn()
	local node = workspace
	for _, name in HubConfig.ARENA_SPAWN_PATH do
		node = node:FindFirstChild(name)
		if not node then
			return nil
		end
	end
	return node
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
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function refreshLeaderboardBoard()
	if not hubFolder then
		return
	end
	HubWorldBuilder.createLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
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

local function playerInZone(root, zonePart)
	local rel = zonePart.CFrame:PointToObjectSpace(root.Position)
	local half = zonePart.Size * 0.5
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function findPlayerZone(player)
	if not hubFolder or inArena[player] then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return nil
	end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") and zonePart.Name:match("Zone$") and playerInZone(root, zonePart) then
			return zonePart
		end
	end
	return nil
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	teleportCharacter(player, HubConfig.SPAWN)
	remotes.ReturnToHub:FireClient(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
	playerZones[player] = nil
	sendZoneHint(player, nil)
end

local function enterArena(player)
	local spawn = getArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Workspace.Arena.Bowl.Spawn anlegen")
		return
	end

	inArena[player] = true
	playerZones[player] = nil
	sendZoneHint(player, nil)

	local target = spawn:IsA("BasePart") and spawn.Position or HubConfig.SPAWN
	teleportCharacter(player, target + Vector3.new(0, 3, 0))

	local lobby = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function handleZoneAction(player, action)
	if inArena[player] then
		return
	end

	if action == "enterArena" then
		enterArena(player)
	elseif action == "openBeySelect" then
		openBeySelect(player)
	elseif action == "viewLeaderboard" then
		refreshLeaderboardBoard()
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not inArena[player] then
			teleportCharacter(player, HubConfig.SPAWN)
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
		end
	end)

	if player.Character then
		teleportCharacter(player, HubConfig.SPAWN)
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
	inArena[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	hubFolder = HubWorldBuilder.build()
	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			handleZoneAction(player, action)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < HubConfig.ZONE_CHECK_INTERVAL then
			return
		end
		elapsed = 0

		for _, player in Players:GetPlayers() do
			if inArena[player] then
				continue
			end
			local zone = findPlayerZone(player)
			if playerZones[player] ~= zone then
				playerZones[player] = zone
				sendZoneHint(player, zone)
			end
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
