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

local function getZoneById(zoneId)
	return HubConfig.ZONES[zoneId]
end

local function getPlayerCount()
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InArena") ~= true then
			count += 1
		end
	end
	return math.max(count, 1)
end

local function getModeLabel()
	local active = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InArena") ~= true then
			table.insert(active, player)
		end
	end
	local count = #active
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.buildLobbyPayload(player)
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

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	player:SetAttribute("InArena", false)
	player:SetAttribute("InHub", true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

local function startArena(player)
	player:SetAttribute("InArena", true)
	player:SetAttribute("InHub", false)
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	if _G.NovaBladersStartArena then
		_G.NovaBladersStartArena(player)
	end
end

local function openBeySelect(player)
	if _G.NovaBladersOpenBeySelect then
		_G.NovaBladersOpenBeySelect(player)
	else
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = true
		end
	end
end

local function openLobby(player)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

local function handleZoneAction(player, zoneId)
	local zone = getZoneById(zoneId)
	if not zone then
		return
	end

	if zone.action == "EnterArena" then
		startArena(player)
	elseif zone.action == "OpenBeySelect" then
		openBeySelect(player)
	elseif zone.action == "OpenLobby" then
		openLobby(player)
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player:SetAttribute("InHub", true)
	player:SetAttribute("InArena", false)
	playerZones[player] = nil

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if player:GetAttribute("InArena") ~= true then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerZones[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		startArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		openBeySelect(player)
	end)

	remotes.HubInteract.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then
			return
		end
		handleZoneAction(player, zoneId)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
