local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
local playerZones = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name, true)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
		local bowl = arena:FindFirstChild("Bowl", true)
		if bowl and bowl:IsA("BasePart") then
			return bowl
		end
	end
	return nil
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		inHub = inHub,
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP),
	}
end

local function sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

local function refreshLeaderboardBoard()
	if not hub then return end
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP)
	HubWorldBuilder.buildLeaderboardBoard(hub, entries)
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local spawn = hub and hub:FindFirstChild("HubSpawn")
	local target = spawn and spawn.Position or (HubConfig.FLOOR_POSITION + HubConfig.SPAWN_OFFSET)
	root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
	playerZones[player] = nil
	sendLobbyReady(player, true)
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
		root.CFrame = CFrame.new(0, 10, 0)
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Fallback-Position genutzt.")
	end

	playerZones[player] = nil
	sendLobbyReady(player, false)
end

local function onZoneEntered(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if playerZones[player] == zoneId then return end
	playerZones[player] = zoneId
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zone.name,
		hint = zone.hint,
		action = zone.action,
	})
end

local function bindZone(zonePart)
	local zoneId = zonePart:GetAttribute("ZoneId")
	if not zoneId then return end

	zonePart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		onZoneEntered(player, zoneId)
	end)

	local prompt = zonePart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			HubWorldManager.handleZoneAction(player, zoneId)
		end)
	end
end

function HubWorldManager.handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "arena" then
		teleportToArena(player)
	elseif zone.action == "beyselect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "leaderboard" then
		refreshLeaderboardBoard()
		sendLobbyReady(player, true)
	end
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	refreshLeaderboardBoard()
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	local zonesFolder = hub:FindFirstChild("Zones")
	if zonesFolder then
		for _, zonePart in zonesFolder:GetChildren() do
			if zonePart:IsA("BasePart") then
				bindZone(zonePart)
			end
		end
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		HubWorldManager.handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				teleportToHub(player)
				refreshLeaderboardBoard()
			end)
		end)
	end)

	local function setupExistingPlayer(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				teleportToHub(player)
				refreshLeaderboardBoard()
			end)
		end)
		if player.Character then
			teleportToHub(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerZones[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		setupExistingPlayer(player)
	end

	refreshLeaderboardBoard()
end

return HubWorldManager
