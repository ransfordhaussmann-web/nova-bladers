local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubModel
local remotes
local playersInHub = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_NAMES do
		local current = workspace
		for segment in string.gmatch(path, "[^%.]+") do
			current = current and current:FindFirstChild(segment)
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
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
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function updateStatsBoard(player)
	if not hubModel then return end
	local board = hubModel:FindFirstChild("StatsBoard")
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("BoardText")
	if not label then return end

	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local lines = {
		"Ruhmeshalle",
		string.format("%s", player.DisplayName),
		string.format("Wins: %d  Losses: %d", data.Wins, data.Losses),
		string.format("Rank-Punkte: %d", rankPoints),
		"",
		"Top Spieler:",
	}
	for _, entry in LeaderboardManager.getTop(5) do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 6 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
end

local function teleportToArena(player)
	local spawn = resolveArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Hub-Teleport übersprungen")
		return false
	end
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	return true
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		playersInHub[player] = false
		if teleportToArena(player) then
			remotes.LobbyReady:FireClient(player, { inHub = false })
		else
			playersInHub[player] = true
		end
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		-- BeySelect-GUI wird clientseitig geöffnet; Server bestätigt nur Hub-Status
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		updateStatsBoard(player)
		remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	end)
end

function HubWorldManager.spawnPlayerInHub(player)
	playersInHub[player] = true
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	player.CharacterAdded:Connect(function()
		if playersInHub[player] then
			task.defer(teleportToHub, player)
		end
	end)

	if player.Character then
		teleportToHub(player)
	end

	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	updateStatsBoard(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportToHub(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	updateStatsBoard(player)
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

Players.PlayerRemoving:Connect(function(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end)

return HubWorldManager
