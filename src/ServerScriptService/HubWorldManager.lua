local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
local playersInHub = {}
local activeZone = {}

local function findArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end

	local bowl = arena:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn")
			or bowl:FindFirstChildWhichIsA("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local fallback = arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if fallback then
		return fallback.CFrame + Vector3.new(0, 3, 0)
	end

	return CFrame.new(0, 10, 0)
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

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)

	local rank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		inHub = true,
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
	}
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.sendLobbyState(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	activeZone[player] = nil
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
	HubWorldManager.sendLobbyState(player)
	remotes.HubZoneHint:FireClient(player, { visible = false })
end

local function enterArena(player)
	playersInHub[player] = nil
	activeZone[player] = nil
	remotes.HubZoneHint:FireClient(player, { visible = false })

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end

	local cframe = findArenaSpawnCFrame()
	teleportCharacter(player, cframe)
end

local function openBeySelect(player)
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function refreshLeaderboardBoard()
	local entries = LeaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.updateLeaderboardBoard(hub, entries)
end

local function onZoneEntered(player, zonePart)
	local zoneId = zonePart:GetAttribute("ZoneId")
	if not zoneId then return end

	activeZone[player] = zoneId
	remotes.HubZoneHint:FireClient(player, {
		visible = true,
		zoneId = zoneId,
		hint = zonePart:GetAttribute("ZoneHint") or "Interagieren",
		key = HubConfig.ZONE_ACTION_KEY.Name,
	})
end

local function onZoneLeft(player)
	activeZone[player] = nil
	remotes.HubZoneHint:FireClient(player, { visible = false })
end

local function bindZone(zonePart)
	zonePart.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player or not playersInHub[player] then return end
		onZoneEntered(player, zonePart)
	end)

	zonePart.TouchEnded:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		if activeZone[player] == zonePart:GetAttribute("ZoneId") then
			onZoneLeft(player)
		end
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	playersInHub[player] = true

	player.CharacterAdded:Connect(function()
		if playersInHub[player] then
			task.defer(function()
				teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
				HubWorldManager.sendLobbyState(player)
			end)
		end
	end)

	if player.Character then
		task.defer(function()
			teleportCharacter(player, CFrame.new(HubConfig.SPAWN_POSITION))
			HubWorldManager.sendLobbyState(player)
		end)
	end
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	activeZone[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()

	local zones = hub:FindFirstChild("Zones")
	if zones then
		for _, child in zones:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("ZoneId") then
				bindZone(child)
			end
		end
	end

	refreshLeaderboardBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
		if not playersInHub[player] then return end
		if activeZone[player] ~= zoneId then return end

		if zoneId == "arena" then
			enterArena(player)
		elseif zoneId == "beylab" then
			openBeySelect(player)
		elseif zoneId == "hall" then
			refreshLeaderboardBoard()
			HubWorldManager.sendLobbyState(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(30)
			refreshLeaderboardBoard()
		end
	end)
end

return HubWorldManager
