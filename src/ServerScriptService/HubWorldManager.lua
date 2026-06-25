local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local playerLocation = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
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
		inHub = playerLocation[player] == "hub",
	}
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function setPlayerLocation(player, location)
	playerLocation[player] = location
	player:SetAttribute("NovaBladersLocation", location)
	remotes.HubState:FireClient(player, location)
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function getZoneById(zoneId)
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function isPlayerNearZone(player, zone)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	return (root.Position - zone.position).Magnitude <= HubConfig.INTERACT_DISTANCE
end

function HubWorldManager.returnToHub(player)
	setPlayerLocation(player, "hub")
	teleportPlayer(player, HubConfig.SPAWN_POSITION)
	sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	setPlayerLocation(player, "arena")
	teleportPlayer(player, HubConfig.ARENA_SPAWN)
end

local function handleZoneAction(player, zone)
	if zone.action == "enter_arena" then
		HubWorldManager.enterArena(player)
	elseif zone.action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "show_stats" then
		local payload = buildLobbyPayload(player)
		payload.showPanel = true
		remotes.LobbyReady:FireClient(player, payload)
	end
end

local function onHubInteract(player, zoneId)
	if playerLocation[player] ~= "hub" then return end
	if typeof(zoneId) ~= "string" then return end

	local zone = getZoneById(zoneId)
	if not zone or not isPlayerNearZone(player, zone) then return end

	handleZoneAction(player, zone)
end

local function onEnterArena(player)
	if playerLocation[player] ~= "hub" then return end
	HubWorldManager.enterArena(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	setPlayerLocation(player, "hub")

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playerLocation[player] == "hub" then
				teleportPlayer(player, HubConfig.SPAWN_POSITION)
			elseif playerLocation[player] == "arena" then
				teleportPlayer(player, HubConfig.ARENA_SPAWN)
			end
		end)
	end)

	sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	PlayerDataManager.save(player)
	playerLocation[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.HubInteract.OnServerEvent:Connect(onHubInteract)
	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
	_G.NovaBladersEnterArena = function(player)
		HubWorldManager.enterArena(player)
	end
end

return HubWorldManager
