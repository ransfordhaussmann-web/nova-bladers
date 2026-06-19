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
local hub
local inHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = Workspace
		for _, name in path do
			current = current and current:FindFirstChild(name)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.sendLobbyReady(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = options.inHub ~= nil and options.inHub or HubWorldManager.isInHub(player),
		showStats = options.showStats == true,
	})
end

function HubWorldManager.spawnInHub(player)
	inHub[player] = true
	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	local spawnCFrame = HubWorldBuilder.getSpawnCFrame(hub)
	teleportCharacter(player, spawnCFrame)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	inHub[player] = true
	local spawnCFrame = HubWorldBuilder.getSpawnCFrame(hub)
	teleportCharacter(player, spawnCFrame)
	HubWorldManager.sendLobbyReady(player)
end

local function enterArena(player)
	if not inHub[player] then
		return
	end

	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — prüfe Workspace.Arena.ArenaSpawn")
		return
	end

	inHub[player] = false
	teleportCharacter(player, arenaSpawn.CFrame + Vector3.new(0, 3, 0))
	HubWorldManager.sendLobbyReady(player)
end

local function openBeySelect(player)
	if not inHub[player] then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end

local function onZoneTriggered(player, zoneId)
	if not inHub[player] then
		return
	end

	if zoneId == "ArenaGate" then
		enterArena(player)
	elseif zoneId == "BeyLab" then
		openBeySelect(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyReady(player, { showStats = true })
	end
end

local function connectZonePrompts()
	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local prompt = zonePart:FindFirstChild("HubPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function(player)
					local zoneId = zonePart:GetAttribute("ZoneId")
					onZoneTriggered(player, zoneId)
				end)
			end
		end
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build(Workspace)
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if inHub[player] then
			enterArena(player)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		HubWorldManager.spawnInHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		inHub[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.spawnInHub(player)
	end
end

return HubWorldManager
