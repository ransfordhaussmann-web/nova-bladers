local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
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

local function teleportToPart(player, part)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
end

function HubWorldManager.buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

function HubWorldManager.sendLobbyState(player, inHub)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player, inHub))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local spawn = hubModel:FindFirstChild("HubSpawn")
	if spawn then
		player.RespawnLocation = spawn
		teleportToPart(player, spawn)
	end
	HubWorldManager.sendLobbyState(player, true)
end

function HubWorldManager.returnToHub(player)
	remotes.ReturnToHub:FireClient(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Workspace.Arena.ArenaSpawn anlegen.")
		return
	end
	inArena[player] = true
	teleportToPart(player, arenaSpawn)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player, false))
end

function HubWorldManager.openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.showHallOfFame(player)
	HubWorldManager.sendLobbyState(player, false)
end

local function onZoneTriggered(player, zoneId)
	if inArena[player] then return end
	if zoneId == "ArenaGate" then
		HubWorldManager.enterArena(player)
	elseif zoneId == "BeyLab" then
		HubWorldManager.openBeySelect(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.showHallOfFame(player)
	end
end

local function connectZonePrompts()
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end
	for zoneId, _ in HubConfig.ZONES do
		local zonePart = zones:FindFirstChild(zoneId)
		local prompt = zonePart and zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, zoneId)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		if not inArena[player] then
			task.defer(function()
				HubWorldManager.spawnInHub(player)
			end)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	else
		HubWorldManager.sendLobbyState(player, true)
	end
end

local function onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
