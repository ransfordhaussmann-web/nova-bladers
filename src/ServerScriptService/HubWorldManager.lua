local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playerZones = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function getZoneConfig(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function findZoneAtPosition(position)
	local zonesFolder = hubModel and hubModel:FindFirstChild("Zones")
	if not zonesFolder then
		return nil
	end

	local closestZone
	local closestDistance = HubConfig.INTERACT_DISTANCE

	for _, zonePart in zonesFolder:GetChildren() do
		if zonePart:IsA("BasePart") then
			local half = zonePart.Size * 0.5
			local localPos = zonePart.CFrame:PointToObjectSpace(position)
			local inside = math.abs(localPos.X) <= half.X
				and math.abs(localPos.Y) <= half.Y + 4
				and math.abs(localPos.Z) <= half.Z

			if inside then
				local distance = (Vector3.new(zonePart.Position.X, 0, zonePart.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestZone = zonePart:GetAttribute("ZoneId")
				end
			end
		end
	end

	return closestZone
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.startArena(player)
	remotes.EnterArena:FireClient(player)
end

local function setPlayerZone(player, zoneId)
	playerZones[player] = zoneId

	local zoneConfig = zoneId and getZoneConfig(zoneId)
	remotes.HubZoneHint:FireClient(player, zoneConfig and {
		zoneId = zoneConfig.id,
		name = zoneConfig.name,
		hint = zoneConfig.hint,
		action = zoneConfig.action,
	} or nil)

	if zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyReady(player)
	end
end

local function handleZoneAction(player, zoneId)
	local zoneConfig = getZoneConfig(zoneId)
	if not zoneConfig then
		return
	end

	if zoneConfig.action == "arena" then
		HubWorldManager.onEnterArena(player)
	elseif zoneConfig.action == "beySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneConfig.action == "stats" then
		HubWorldManager.sendLobbyReady(player)
	end
end

function HubWorldManager.onEnterArena(player)
	-- Hook point for GameManager: arena start is triggered via EnterArena remote.
	-- GameManager in Studio should listen to remotes.EnterArena.OnServerEvent.
end

local function onCharacterAdded(player, _character)
	task.defer(function()
		HubWorldManager.teleportToHub(player)
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()

	remotes.HubInteract.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then
			return
		end
		local currentZone = playerZones[player]
		if currentZone ~= zoneId then
			return
		end
		handleZoneAction(player, zoneId)
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.onEnterArena(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local zoneId = findZoneAtPosition(root.Position)
					if playerZones[player] ~= zoneId then
						setPlayerZone(player, zoneId)
					end
				end
			end
			task.wait(0.2)
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
	_G.NovaBladersStartArena = function(player)
		HubWorldManager.onEnterArena(player)
	end
end

return HubWorldManager
