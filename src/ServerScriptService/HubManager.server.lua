local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers:WaitForChild("HubWorldBuilder"))
local HubConfig = require(NovaBladers:WaitForChild("HubConfig"))
local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
local LeaderboardManager = require(script.Parent:WaitForChild("LeaderboardManager"))

local remotesFolder = NovaBladers:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = NovaBladers
end

local function getOrCreateRemote(name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local LobbyReady = getOrCreateRemote("LobbyReady")
local EnterArena = getOrCreateRemote("EnterArena")
local HubStateChanged = getOrCreateRemote("HubStateChanged")

local hub = HubWorldBuilder.build()
local lobbyPlayers = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
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

local function sendLobbyReady(player)
	if not lobbyPlayers[player] then
		return
	end
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function broadcastLobbyModes()
	for player in lobbyPlayers do
		sendLobbyReady(player)
	end
end

local function teleportToHub(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
end

local function isNearArenaGate(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return (root.Position - HubConfig.ARENA_GATE).Magnitude <= HubConfig.GATE_RADIUS
end

local function enterArena(player, forceEntry)
	if player:GetAttribute("InArena") then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	if not forceEntry and not isNearArenaGate(character) then
		return
	end

	lobbyPlayers[player] = nil
	player:SetAttribute("InHub", false)
	player:SetAttribute("InArena", true)

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = HubWorldBuilder.getArenaSpawnCFrame()
	end

	HubStateChanged:FireClient(player, { inHub = false, inArena = true })
end

local function setHubState(player)
	lobbyPlayers[player] = true
	player:SetAttribute("InHub", true)
	player:SetAttribute("InArena", false)
	HubStateChanged:FireClient(player, { inHub = true, inArena = false })
	sendLobbyReady(player)
end

local function onCharacterAdded(player, character)
	if player:GetAttribute("InArena") then
		return
	end
	task.defer(function()
		teleportToHub(character)
	end)
end

Players.PlayerAdded:Connect(function(player)
	local data = PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	setHubState(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lobbyPlayers[player] = nil
	PlayerDataManager.save(player)
	broadcastLobbyModes()
end)

EnterArena.OnServerEvent:Connect(function(player, forceEntry)
	enterArena(player, forceEntry == true)
end)

Players.PlayerAdded:Connect(function()
	task.defer(broadcastLobbyModes)
end)

Players.PlayerRemoving:Connect(function()
	task.defer(broadcastLobbyModes)
end)

return {
	hub = hub,
	sendLobbyReady = sendLobbyReady,
	setHubState = setHubState,
}
