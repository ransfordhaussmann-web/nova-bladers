local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playerZones = {}
local playersInArena = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if not arena then return nil end

	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	local bowl = arena:FindFirstChild("Bowl") or workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl
	end

	return nil
end

local function teleportCharacter(character, position)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not playersInArena[player],
		inArena = playersInArena[player] == true,
	}
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function refreshLeaderboardBoard()
	if not hubFolder then return end
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, LeaderboardManager.getTop(5))
end

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function setPlayerZone(player, zoneId)
	local previous = playerZones[player]
	if previous == zoneId then return end

	playerZones[player] = zoneId
	local zone = zoneId and getZoneConfig(zoneId)
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zoneId,
		name = zone and zone.name,
		hint = zone and zone.hint,
		action = zone and zone.action,
	})
end

local function bindZoneTrigger(trigger)
	local zoneIdValue = trigger:FindFirstChild("ZoneId")
	if not zoneIdValue then return end
	local zoneId = zoneIdValue.Value

	trigger.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or playersInArena[player] then return end
		setPlayerZone(player, zoneId)
	end)

	trigger.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or playerZones[player] ~= zoneId then return end

		task.defer(function()
			if playerZones[player] ~= zoneId then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then
				setPlayerZone(player, nil)
				return
			end
			local distance = (root.Position - trigger.Position).Magnitude
			if distance > math.max(trigger.Size.X, trigger.Size.Z) then
				setPlayerZone(player, nil)
			end
		end)
	end)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	playersInArena[player] = nil
	teleportCharacter(character, HubConfig.SPAWN_POSITION)
	sendLobbyReady(player)
	setPlayerZone(player, nil)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.enterArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[HubWorldManager] Kein Arena-Spawn gefunden")
		return false
	end

	local character = player.Character
	if not character then return false end

	playersInArena[player] = true
	setPlayerZone(player, nil)
	teleportCharacter(character, spawn.Position + Vector3.new(0, 3, 0))
	sendLobbyReady(player)
	return true
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.handleZoneAction(player, zoneId)
	if playersInArena[player] then return end

	local zone = getZoneConfig(zoneId)
	if not zone or not zone.action then return end

	if zone.action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "OpenBeySelect" then
		HubWorldManager.openBeySelect(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()

	local zonesFolder = hubFolder:FindFirstChild("Zones")
	if zonesFolder then
		for _, zoneFolder in zonesFolder:GetChildren() do
			local trigger = zoneFolder:FindFirstChild("Trigger")
			if trigger then
				bindZoneTrigger(trigger)
			end
		end
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then return end
		HubWorldManager.handleZoneAction(player, zoneId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		playersInArena[player] = nil
		PlayerDataManager.save(player)
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
		refreshLeaderboardBoard()
		sendLobbyReady(player)

		player.CharacterAdded:Connect(function()
			if not playersInArena[player] then
				task.defer(function()
					HubWorldManager.teleportToHub(player)
				end)
			end
		end)

		if player.Character and not playersInArena[player] then
			task.defer(function()
				HubWorldManager.teleportToHub(player)
			end)
		end
	end

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
end

return HubWorldManager
