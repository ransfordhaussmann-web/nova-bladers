local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ARENA_FALLBACK)
end

local function getHubSpawn()
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN)
end

local function teleportPlayer(player, cf)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end

function HubWorldManager.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	})
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	teleportPlayer(player, getHubSpawn())
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	inArena[player] = nil
	HubWorldManager.spawnInHub(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	teleportPlayer(player, resolveArenaSpawn())
	remotes.EnterArena:FireClient(player)
end

local function onEnterArena(player)
	if inArena[player] then return end
	HubWorldManager.enterArena(player)
end

local function onZoneAction(player, zoneId)
	if inArena[player] then return end

	if zoneId == "ArenaGate" then
		onEnterArena(player)
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyReady(player)
		remotes.ShowHallPanel:FireClient(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.HubZoneAction.OnServerEvent:Connect(onZoneAction)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			if not inArena[player] then
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end
end

return HubWorldManager
