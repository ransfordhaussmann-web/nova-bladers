local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local leaderboardBoard
local playersInHub = {}
local arenaOccupants = {}

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
	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	local bowl = Workspace:FindFirstChild("Bowl")
	if bowl then
		local spawn = bowl:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return nil
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

local function refreshLeaderboardBoard()
	if not leaderboardBoard then return end
	HubWorldBuilder.updateLeaderboardBoard(leaderboardBoard, LeaderboardManager.getTop(5))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	playersInHub[player] = true
	arenaOccupants[player] = nil
end

local function teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — HubSpawn wird genutzt")
		teleportToHub(player)
		return false
	end

	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	playersInHub[player] = nil
	arenaOccupants[player] = true
	return true
end

function HubWorldManager.sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	HubWorldManager.sendLobbyReady(player, true)
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

local function onEnterArena(player)
	if arenaOccupants[player] then return end
	if not teleportToArena(player) then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, false))
end

local function onZoneActivated(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone then return end

	if zone.action == "enterArena" then
		onEnterArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showLeaderboard" then
		refreshLeaderboardBoard()
		remotes.HubZoneHint:FireClient(player, zone.hint)
	end
end

local function wireZonePrompts()
	if not hubFolder then return end
	local zonesFolder = hubFolder:FindFirstChild("Zones")
	if not zonesFolder then return end

	for _, marker in zonesFolder:GetChildren() do
		local prompt = marker:FindFirstChild("ZonePrompt")
		if prompt then
			local zoneId = marker:GetAttribute("zoneId")
			prompt.Triggered:Connect(function(player)
				onZoneActivated(player, zoneId)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)

	local function setupCharacter(character)
		task.defer(function()
			teleportToHub(player)
			HubWorldManager.sendLobbyReady(player, true)
		end)
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playersInHub[player] = nil
	arenaOccupants[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	local topEntries = LeaderboardManager.getTop(5)
	hubFolder = HubWorldBuilder.build(Workspace, topEntries)
	leaderboardBoard = hubFolder:FindFirstChild("LeaderboardBoard")

	wireZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

return HubWorldManager
