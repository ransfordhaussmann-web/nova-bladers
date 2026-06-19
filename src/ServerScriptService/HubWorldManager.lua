local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local inHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = game
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = Workspace
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

local function getArenaCFrame()
	local spawn = findArenaSpawn()
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 5, 0)
end

local function teleportPlayer(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	teleportPlayer(player, HubWorldBuilder.getSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.teleportToArena(player)
	inHub[player] = false
	teleportPlayer(player, getArenaCFrame())
	remotes.EnterArena:FireClient(player)
end

function HubWorldManager.isInHub(player)
	return inHub[player] ~= false
end

local function onEnterArena(player)
	if not inHub[player] then
		return
	end
	HubWorldManager.teleportToArena(player)
end

local function onReturnToHub(player)
	HubWorldManager.returnToHub(player)
end

local function onZoneAction(player, action)
	if not inHub[player] then
		return
	end

	if action == "enterArena" then
		onEnterArena(player)
	elseif action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "showHall" then
		remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	inHub[player] = true

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if inHub[player] then
			teleportPlayer(player, HubWorldBuilder.getSpawnCFrame())
		end
	end)

	task.defer(function()
		HubWorldManager.sendLobbyReady(player)
	end)
end

local function onPlayerRemoving(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
	PlayerDataManager.save(player)
	inHub[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.ReturnToHub.OnServerEvent:Connect(onReturnToHub)
	remotes.HubZoneAction.OnServerEvent:Connect(onZoneAction)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
