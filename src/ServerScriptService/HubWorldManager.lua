local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
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
		local current = workspace
		for _, segment in path do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getHubSpawnCFrame()
	if hubFolder then
		local spawn = hubFolder:FindFirstChild("HubSpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

function HubWorldManager.buildHub()
	hubFolder = HubWorldBuilder.build()
	return hubFolder
end

function HubWorldManager.isInHub(player)
	return inHub[player] == true
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = getHubSpawnCFrame()
	inHub[player] = true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyPayload(player, true)
end

function HubWorldManager.sendLobbyPayload(player, hideGui)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local payload = {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		hideGui = hideGui == true,
	}
	remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.enterArena(player)
	if not inHub[player] then return end
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Arena.ArenaSpawn in Workspace anlegen.")
		return
	end
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	inHub[player] = false
	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			HubWorldManager.teleportToHub(player)
			HubWorldManager.sendLobbyPayload(player, true)
		end)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
		HubWorldManager.sendLobbyPayload(player, true)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	inHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.getRemotes()
	HubWorldManager.buildHub()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not inHub[player] then return end
		remotes.OpenBeySelect:FireClient(player)
	end)

	remotes.ShowHallPanel.OnServerEvent:Connect(function(player)
		if not inHub[player] then return end
		HubWorldManager.sendLobbyPayload(player, false)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
