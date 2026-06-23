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
local hubFolder

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. playerCount .. " Spieler)"
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_PATHS do
		local node = workspace
		for _, name in path do
			node = node and node:FindFirstChild(name)
		end
		if node then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = node:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
			if node:IsA("BasePart") then
				return node.CFrame + Vector3.new(0, 5, 0)
			end
		end
	end
	return CFrame.new(0, 10, 0)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = playersInHub[player] == true,
	}
end

function HubWorldManager.sendLobbyState(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	local look = HubConfig.SPAWN_LOOK_AT
	local spawnPos = HubConfig.SPAWN_POSITION
	local cframe = CFrame.lookAt(spawnPos, look)
	teleportCharacter(player, cframe)
	HubWorldManager.sendLobbyState(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	playersInHub[player] = nil
	local arenaCFrame = findArenaSpawn()
	teleportCharacter(player, arenaCFrame)
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.refreshLeaderboardBoard()
	if not hubFolder then
		return
	end
	local board = hubFolder:FindFirstChild("LeaderboardBoard", true)
	if board then
		board:Destroy()
	end
	local entries = leaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, entries)
end

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager

	remotes = RemotesSetup.ensure()
	local entries = leaderboardManager.getTop(HubConfig.LEADERBOARD_TOP_COUNT)
	hubFolder = HubWorldBuilder.build(entries)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then
			return
		end
		HubWorldManager.teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then
			return
		end
		remotes.OpenBeySelect:FireClient(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if not playersInHub[player] then
			return
		end
		if action == "EnterArena" then
			HubWorldManager.teleportToArena(player)
		elseif action == "OpenBeySelect" then
			remotes.OpenBeySelect:FireClient(player)
		elseif action == "ViewLeaderboard" then
			HubWorldManager.refreshLeaderboardBoard()
			HubWorldManager.sendLobbyState(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		playerDataManager.load(player)
		local data = playerDataManager.get(player)
		local rankPoints = playerDataManager.getRankPoints(data)
		leaderboardManager.submit(player, rankPoints)

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if playersInHub[player] ~= false then
				HubWorldManager.spawnInHub(player)
			end
		end)

		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerDataManager.save(player)
		playersInHub[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if not playerDataManager.get(player) then
			playerDataManager.load(player)
		end
		HubWorldManager.spawnInHub(player)
	end
end

return HubWorldManager
