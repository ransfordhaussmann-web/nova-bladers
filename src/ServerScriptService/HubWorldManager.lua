local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local playerDataManager
local leaderboardManager
local playersInHub = {}
local zoneDebounce = {}

local function getCharacterRoot(player)
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end
	local bowl = arena:FindFirstChild("Bowl")
	if bowl then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = bowl:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end
	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return nil
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local wins = data.Wins or 0
	local losses = data.Losses or 0
	local points = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(5)

	return {
		wins = wins,
		losses = losses,
		rank = points,
		modeLabel = HubWorldManager.getModeLabel(),
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.sendLobbyState(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.refreshLeaderboardBoard()
	HubWorldBuilder.updateLeaderboardBoard(leaderboardManager.getTop(5))
end

function HubWorldManager.spawnInHub(player)
	local root = getCharacterRoot(player)
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION, HubConfig.SPAWN_POSITION + HubConfig.SPAWN_LOOK)
	playersInHub[player] = true
	HubWorldManager.sendLobbyState(player)
	HubWorldManager.refreshLeaderboardBoard()
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	local root = getCharacterRoot(player)
	if not root then return end

	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 6, 0)
	end
	playersInHub[player] = nil
end

local function onZoneTouched(zonePart, hit)
	local character = hit.Parent
	if not character then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or not playersInHub[player] then return end

	local key = player.UserId .. "_" .. zonePart.Name
	if zoneDebounce[key] then return end
	zoneDebounce[key] = true
	task.delay(1.5, function()
		zoneDebounce[key] = nil
	end)

	local hint = zonePart:GetAttribute("ZoneHint") or zonePart:GetAttribute("ZoneName")
	local action = zonePart:GetAttribute("ZoneAction")
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zonePart:GetAttribute("ZoneId"),
		name = zonePart:GetAttribute("ZoneName"),
		hint = hint,
		action = action,
	})
end

local function bindZones(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end
	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			zonePart.Touched:Connect(function(hit)
				onZoneTouched(zonePart, hit)
			end)
		end
	end
end

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager

	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()
	bindZones(workspace:FindFirstChild(HubConfig.FOLDER_NAME))

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		HubWorldManager.teleportToArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if not playersInHub[player] then return end
		if action == "EnterArena" then
			HubWorldManager.teleportToArena(player)
		elseif action == "OpenBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "ShowLeaderboard" then
			HubWorldManager.sendLobbyState(player)
			HubWorldManager.refreshLeaderboardBoard()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
	end)
end

function HubWorldManager.onPlayerReady(player)
	HubWorldManager.spawnInHub(player)
	local data = playerDataManager.get(player)
	leaderboardManager.submit(player, playerDataManager.getRankPoints(data))
	HubWorldManager.refreshLeaderboardBoard()
end

return HubWorldManager
