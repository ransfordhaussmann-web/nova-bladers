local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local zoneParts = {}
local playersInHub = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function findArenaCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if spawn then
			if spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
			if spawn:IsA("SpawnLocation") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	for _, name in { "Bowl", "ArenaBowl" } do
		local bowl = workspace:FindFirstChild(name)
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + Vector3.new(0, bowl.Size.Y * 0.5 + 3, 0)
		end
	end

	return CFrame.new(0, 10, 0)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	character:PivotTo(targetCFrame)
	return true
end

local function getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + HubConfig.SPAWN_OFFSET
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

function HubWorldManager.updateLeaderboardBoard()
	local hallZone = HubConfig.ZONES[3]
	if not hallZone then
		return
	end
	local hub = workspace:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	if not hub then
		return
	end
	local entries = LeaderboardManager.getTop(5)
	HubWorldBuilder.buildLeaderboardBoard(hub, hallZone, entries)
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
		inHub = playersInHub[player] == true,
	})
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	player.CharacterAdded:Connect(function()
		if playersInHub[player] then
			task.defer(function()
				teleportCharacter(player, getHubSpawnCFrame())
			end)
		end
	end)
	if player.Character then
		teleportCharacter(player, getHubSpawnCFrame())
	end
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportCharacter(player, getHubSpawnCFrame())
	HubWorldManager.sendLobbyReady(player)
	HubWorldManager.updateLeaderboardBoard()
end

local function enterArena(player)
	playersInHub[player] = false
	teleportCharacter(player, findArenaCFrame())
	HubWorldManager.sendLobbyReady(player)
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local function showLeaderboard(player)
	HubWorldManager.updateLeaderboardBoard()
	remotes.HubZoneHint:FireClient(player, "Top 5 auf dem Board in der Ruhmeshalle", "Ruhmeshalle")
end

local ZONE_ACTIONS = {
	enter_arena = enterArena,
	open_bey_select = openBeySelect,
	show_leaderboard = showLeaderboard,
}

local function runZoneAction(player, action)
	local handler = ZONE_ACTIONS[action]
	if handler then
		handler(player)
	end
end

local function onZoneTouched(zonePart, hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player or not playersInHub[player] then
		return
	end

	local zoneId = zonePart:GetAttribute("ZoneId")
	for _, zone in HubConfig.ZONES do
		if zone.id == zoneId then
			remotes.HubZoneHint:FireClient(player, zone.hint, zone.name)
			break
		end
	end
end

local function bindZone(zonePart)
	zonePart.Touched:Connect(function(hit)
		onZoneTouched(zonePart, hit)
	end)

	local prompt = zonePart:FindFirstChild("ZonePrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			local action = prompt:GetAttribute("ZoneAction")
			runZoneAction(player, action)
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local _, builtZones = HubWorldBuilder.build()
	zoneParts = builtZones
	HubWorldManager.updateLeaderboardBoard()

	for _, zonePart in zoneParts do
		bindZone(zonePart)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInHub[player] then
			enterArena(player)
		end
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if playersInHub[player] and typeof(action) == "string" then
			runZoneAction(player, action)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		HubWorldManager.spawnInHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		if not PlayerDataManager.get(player) then
			PlayerDataManager.load(player)
		end
		HubWorldManager.spawnInHub(player)
	end

	task.spawn(function()
		while true do
			task.wait(60)
			HubWorldManager.updateLeaderboardBoard()
		end
	end)
end

return HubWorldManager
