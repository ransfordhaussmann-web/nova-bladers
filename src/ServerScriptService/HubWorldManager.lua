local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local hubFolder
local playerDataManager
local leaderboardManager
local playersInArena = {}

function HubWorldManager.init(deps)
	playerDataManager = deps.PlayerDataManager
	leaderboardManager = deps.LeaderboardManager
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
end

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = folder:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(5)
	HubWorldBuilder.buildLeaderboardBoard(hubFolder, leaderboard)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = not playersInArena[player],
		inArena = playersInArena[player] == true,
	}
end

function HubWorldManager.sendLobbyState(player)
	if not remotes then return end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
	playersInArena[player] = nil
	HubWorldManager.sendLobbyState(player)
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 6, 0)
	end

	playersInArena[player] = true
	HubWorldManager.sendLobbyState(player)
end

function HubWorldManager.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if playersInArena[player] then
				HubWorldManager.teleportToArena(player)
			else
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)
end

function HubWorldManager.connectRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		-- BeySelect GUI is opened client-side; server may validate later.
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if action == "enter_arena" then
			HubWorldManager.teleportToArena(player)
		elseif action == "open_bey_select" then
			remotes.OpenBeySelect:FireClient(player)
		end
	end)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInArena[player] = nil
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

return HubWorldManager
