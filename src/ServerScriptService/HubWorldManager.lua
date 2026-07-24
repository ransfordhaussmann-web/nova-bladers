local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)
local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local playersInHub = {}
local playerSelections = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = game
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.getHubSpawnCFrame()
	local spawnPart = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if spawnPart then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

function HubWorldManager.teleportToHub(player)
	local root = getCharacterRoot(player)
	if not root then
		return
	end
	playersInHub[player] = true
	root.CFrame = HubWorldManager.getHubSpawnCFrame()
end

function HubWorldManager.teleportToArena(player)
	local root = getCharacterRoot(player)
	if not root then
		return
	end
	playersInHub[player] = nil

	local spawnPart = resolveArenaSpawn()
	if spawnPart then
		root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 5, 0)
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.sendLobbyReady(player, true)
	HubWorldManager.teleportToHub(player)
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubFolder then
		return
	end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.createLeaderboardBoard(hubFolder, entries)
end

function HubWorldManager.sendLobbyReady(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = "Modus: Training",
		leaderboard = leaderboard,
		inHub = inHub == true,
	})
end

local function handleZoneAction(player, zoneId)
	if not playersInHub[player] then
		return
	end

	if zoneId == "arena" then
		HubWorldManager.teleportToArena(player)
	elseif zoneId == "beyLab" then
		remotes.BeySelectStart:FireClient(player, {
			catalog = BeyCatalog,
			timeout = BeyConfig.SELECTION_TIMEOUT,
			selectedId = playerSelections[player],
		})
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "hallOfFame" then
		HubWorldManager.refreshLeaderboardBoard()
		remotes.HubZoneHint:FireClient(player, {
			zoneId = "hallOfFame",
			title = "Ruhmeshalle",
			message = "Top 5 auf dem Board links.",
		})
	end
end

local function connectZonePrompts()
	local zonesFolder = hubFolder:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end

	for _, marker in zonesFolder:GetChildren() do
		local prompt = marker:FindFirstChild("ZonePrompt")
		local zoneId = marker:GetAttribute("ZoneId")
		if prompt and zoneId then
			prompt.Triggered:Connect(function(player)
				handleZoneAction(player, zoneId)
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playersInHub[player] ~= false then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end

	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	playerSelections[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	connectZonePrompts()
	HubWorldManager.refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	remotes.BeySelectPick.OnServerEvent:Connect(function(player, beyId)
		if typeof(beyId) ~= "string" then
			return
		end
		for _, bey in BeyCatalog do
			if bey.id == beyId then
				playerSelections[player] = beyId
				return
			end
		end
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(HubWorldManager.onPlayerAdded, player)
	end
end

return HubWorldManager
