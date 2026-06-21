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
local zoneCooldowns = {}
local playersInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name, true)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	for _, name in HubConfig.ARENA_FALLBACK_NAMES do
		local part = workspace:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part.CFrame + Vector3.new(0, 5, 0)
		end
	end

	return CFrame.new(0, 10, 0)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = targetCFrame
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD.topCount)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = playersInHub[player] == true,
	}
end

local function sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD.topCount)
	HubWorldBuilder.updateLeaderboard(entries)
end

local function setPlayerInHub(player, inHub)
	playersInHub[player] = inHub or nil
	sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	if not playersInHub[player] then return end
	setPlayerInHub(player, false)
	teleportCharacter(player, findArenaSpawnCFrame())
end

function HubWorldManager.openBeySelect(player)
	if not playersInHub[player] then return end
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.showZoneHint(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end
	remotes.HubZoneHint:FireClient(player, {
		zoneId = zone.id,
		title = zone.displayName,
		hint = zone.hint,
	})
end

local function handleZoneAction(player, action, zoneId)
	if not playersInHub[player] then return end

	local now = os.clock()
	local key = player.UserId .. "_" .. (zoneId or action)
	if zoneCooldowns[key] and now - zoneCooldowns[key] < HubConfig.ZONE_COOLDOWN then
		return
	end
	zoneCooldowns[key] = now

	if action == "enterArena" then
		HubWorldManager.enterArena(player)
	elseif action == "openBeySelect" then
		HubWorldManager.openBeySelect(player)
	elseif action == "hallOfFame" then
		HubWorldManager.showZoneHint(player, zoneId)
		refreshLeaderboardBoard()
	end
end

local function wireZonePrompts(hub)
	for zoneKey, zone in HubConfig.ZONES do
		local zoneFolder = hub:FindFirstChild(zoneKey)
		if not zoneFolder then continue end
		local pad = zoneFolder:FindFirstChild("Pad")
		local prompt = pad and pad:FindFirstChild("ZonePrompt")
		if not prompt then continue end

		prompt.Triggered:Connect(function(player)
			handleZoneAction(player, zone.action, zoneKey)
		end)
	end
end

function HubWorldManager.spawnInHub(player)
	setPlayerInHub(player, true)
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	refreshLeaderboardBoard()
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playersInHub[player] ~= false then
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end

	refreshLeaderboardBoard()
end

local function onPlayerRemoving(player)
	zoneCooldowns[player.UserId] = nil
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	HubWorldBuilder.build()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		wireZonePrompts(hub)
	end

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	refreshLeaderboardBoard()
end

return HubWorldManager
