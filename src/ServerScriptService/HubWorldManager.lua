local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local HubWorldManager = {}

local remotes
local hubSpawn
local playerState = {}

local function getCharacterRoot(player)
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local arena = workspace:FindFirstChild(folderName)
		if arena then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = arena:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
		end
	end

	for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = workspace:FindFirstChild(spawnName, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end

	return nil
end

local function teleportToPart(player, part, offsetY)
	local root = getCharacterRoot(player)
	if not root or not part then return false end
	root.CFrame = part.CFrame + Vector3.new(0, offsetY or 3, 0)
	return true
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, showGui)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		showGui = showGui,
		inHub = showGui == false,
	}
end

function HubWorldManager.sendLobbyData(player, showGui)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, showGui))
end

function HubWorldManager.setHubState(player, inHub)
	playerState[player] = inHub and "hub" or "arena"
	remotes.HubState:FireClient(player, inHub and "hub" or "arena")
end

function HubWorldManager.teleportToHub(player)
	if not hubSpawn then return end
	teleportToPart(player, hubSpawn, 3)
	HubWorldManager.setHubState(player, true)
	HubWorldManager.sendLobbyData(player, false)
end

function HubWorldManager.teleportToArena(player)
	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Hub-Arena-Tor deaktiviert.")
		return false
	end

	if not teleportToPart(player, arenaSpawn, 3) then
		return false
	end

	HubWorldManager.setHubState(player, false)
	return true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	remotes.ReturnToHub:FireClient(player)
end

local function onZoneTriggered(player, zoneId)
	if playerState[player] ~= "hub" then return end

	if zoneId == "ArenaGate" then
		HubWorldManager.teleportToArena(player)
	elseif zoneId == "BeyLab" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zoneId == "HallOfFame" then
		HubWorldManager.sendLobbyData(player, true)
	end
end

local function connectZonePrompts(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, marker in zones:GetChildren() do
		local prompt = marker:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local zoneId = prompt:GetAttribute("ZoneId") or marker.Name
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
		task.defer(function()
			HubWorldManager.teleportToHub(player)
		end)
	end)

	if player.Character then
		task.defer(function()
			HubWorldManager.teleportToHub(player)
		end)
	end
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	local hub, spawn = HubWorldBuilder.build()
	hubSpawn = spawn
	connectZonePrompts(hub)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
