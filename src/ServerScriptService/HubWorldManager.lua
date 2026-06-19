local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldManager = {}
HubWorldManager._inHub = {}
HubWorldManager._remotes = nil
HubWorldManager._playerDataManager = nil
HubWorldManager._leaderboardManager = nil

local function getArenaSpawnCFrame()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = Workspace
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				continue
			end
			current = current:FindFirstChild(segment)
			if not current then
				break
			end
		end
		if current and current:IsA("BasePart") then
			return current.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 5, 80)
end

local function getHubSpawnCFrame()
	local hub = Workspace:FindFirstChild("NovaHub")
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN)
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.init(remotes, playerDataManager, leaderboardManager)
	HubWorldManager._remotes = remotes
	HubWorldManager._playerDataManager = playerDataManager
	HubWorldManager._leaderboardManager = leaderboardManager
end

function HubWorldManager.buildLobbyPayload(player)
	local data = HubWorldManager._playerDataManager.get(player)
	local rankPoints = HubWorldManager._playerDataManager.getRankPoints(data)
	local leaderboard = HubWorldManager._leaderboardManager.getTop(5)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = leaderboard,
		inHub = HubWorldManager._inHub[player] == true,
	}
end

function HubWorldManager.sendLobbyReady(player)
	HubWorldManager._remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = getHubSpawnCFrame()
end

function HubWorldManager.enterHub(player)
	HubWorldManager._inHub[player] = true
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.enterHub(player)
end

function HubWorldManager.leaveHub(player)
	HubWorldManager._inHub[player] = false
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	HubWorldManager.leaveHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = getArenaSpawnCFrame()
end

function HubWorldManager.onPlayerAdded(player)
	HubWorldManager._playerDataManager.load(player)
	local data = HubWorldManager._playerDataManager.get(player)
	local rankPoints = HubWorldManager._playerDataManager.getRankPoints(data)
	HubWorldManager._leaderboardManager.submit(player, rankPoints)

	local function spawnInHub(character)
		task.defer(function()
			HubWorldManager.enterHub(player)
		end)
	end

	player.CharacterAdded:Connect(spawnInHub)
	if player.Character then
		spawnInHub(player.Character)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	HubWorldManager._playerDataManager.save(player)
	HubWorldManager._inHub[player] = nil
end

return HubWorldManager
