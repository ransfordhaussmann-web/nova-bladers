local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerZones = {}
local inArena = {}

local function getRemotes()
	if remotes then
		return remotes
	end
	remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
	return remotes
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function isInsideZone(position, zone)
	local half = zone.size * 0.5
	local center = zone.position + Vector3.new(0, HubConfig.SPAWN_POSITION.Y - 3.5, 0)
	local localPos = position - center
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y + 4
		and math.abs(localPos.Z) <= half.Z
end

local function detectZone(position)
	for _, zone in pairs(HubConfig.ZONES) do
		if isInsideZone(position, zone) then
			return zone
		end
	end
	return nil
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = "Modus: Training",
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function sendZoneHint(player, zone)
	local remote = getRemotes().HubZoneHint
	if zone then
		remote:FireClient(player, {
			zoneId = zone.id,
			name = zone.name,
			hint = zone.hint,
			action = zone.action,
		})
	else
		remote:FireClient(player, {
			zoneId = nil,
			name = nil,
			hint = "Erkunde den Nova Hub",
			action = nil,
		})
	end
end

function HubWorldManager.teleportToHub(player)
	local root = getCharacterRoot(player)
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	inArena[player] = nil
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	local payload = buildLobbyPayload(player)
	getRemotes().LobbyReady:FireClient(player, payload)
end

function HubWorldManager.startArena(player)
	inArena[player] = true
	getRemotes().EnterArena:FireClient(player)
end

local function handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		return
	end

	if zone.action == "enterArena" then
		inArena[player] = true
	elseif zone.action == "openBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif zone.action == "openStats" then
		getRemotes().LobbyReady:FireClient(player, buildLobbyPayload(player))
	end
end

function HubWorldManager.init()
	getRemotes().HubInteract.OnServerEvent:Connect(function(player, zoneId)
		if inArena[player] then
			return
		end
		handleZoneAction(player, zoneId)
	end)

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		inArena[player] = true
	end)

	Players.PlayerAdded:Connect(function(player)
		playerZones[player] = nil
		inArena[player] = nil

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if not inArena[player] then
				HubWorldManager.teleportToHub(player)
				sendZoneHint(player, nil)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZones[player] = nil
		inArena[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.ZONE_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				if inArena[player] then
					continue
				end
				local root = getCharacterRoot(player)
				if not root then
					continue
				end
				local zone = detectZone(root.Position)
				local previous = playerZones[player]
				local currentId = zone and zone.id or nil
				if previous ~= currentId then
					playerZones[player] = currentId
					sendZoneHint(player, zone)
				end
			end
		end
	end)
end

function HubWorldManager.onPlayerReady(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	sendZoneHint(player, nil)
end

_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
_G.NovaBladersStartArena = HubWorldManager.startArena

return HubWorldManager
