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
local playersInHub = {}

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local parts = string.split(path, ".")
		local current = Workspace
		for _, name in parts do
			current = current and current:FindFirstChild(name)
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
	if not root or not part then return end
	root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player, inHub)
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

function HubWorldManager.sendLobbyReady(player, inHub)
	playersInHub[player] = inHub or false
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	local spawnPart = HubWorldBuilder.getHubSpawn()
	teleportToPart(player, spawnPart)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = false
	local arenaSpawn = findArenaSpawn()
	if arenaSpawn then
		teleportToPart(player, arenaSpawn)
	end
	HubWorldManager.sendLobbyReady(player, false)
end

function HubWorldManager.openBeySelect(player)
	if not playersInHub[player] then return end
	remotes.BeySelectOpen:FireClient(player)
end

function HubWorldManager.showLeaderboard(player)
	if not playersInHub[player] then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, false))
end

function HubWorldManager.refreshLeaderboardDisplay()
	local zonePart = HubWorldBuilder.getZonePart("HallOfFame")
	if zonePart then
		HubWorldBuilder.buildLeaderboardDisplay(zonePart, LeaderboardManager.getTop(5))
	end
end

local function onZonePromptTriggered(prompt, player)
	local action = prompt:GetAttribute("HubAction")
	if not action or not playersInHub[player] then return end

	if action == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "OpenBeySelect" then
		HubWorldManager.openBeySelect(player)
	elseif action == "ShowLeaderboard" then
		HubWorldManager.showLeaderboard(player)
	end
end

local function connectZonePrompts(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				onZonePromptTriggered(prompt, player)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if playersInHub[player] ~= false then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	else
		HubWorldManager.sendLobbyReady(player, true)
	end
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local hub = HubWorldBuilder.build()
	connectZonePrompts(hub)
	HubWorldManager.refreshLeaderboardDisplay()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			HubWorldManager.enterArena(player)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		HubWorldManager.openBeySelect(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(60)
			HubWorldManager.refreshLeaderboardDisplay()
		end
	end)
end

return HubWorldManager
