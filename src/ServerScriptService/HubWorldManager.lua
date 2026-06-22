local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local remotes
local hubModel

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA (" .. count .. " Spieler)"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl then
			local spawn = bowl:FindFirstChild("Spawn") or bowl:FindFirstChildWhichIsA("SpawnLocation")
			if spawn and spawn:IsA("BasePart") then
				return spawn.Position + Vector3.new(0, 4, 0)
			end
		end
		local spawn = arena:FindFirstChild("Spawn") or arena:FindFirstChildWhichIsA("SpawnLocation")
		if spawn and spawn:IsA("BasePart") then
			return spawn.Position + Vector3.new(0, 4, 0)
		end
	end
	return HubConfig.ARENA_FALLBACK
end

local function getPlayerRank(player)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	local top = LeaderboardManager.getTop(50)
	for _, entry in top do
		if entry.name == player.Name then
			return entry.rank
		end
	end
	return 0
end

local function buildLeaderboardText(entries)
	local lines = { "🏆 Top Spieler" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateLeaderboardBoard(entries)
	if not hubModel then return end
	local board = hubModel:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChild("LeaderboardGui")
	local label = gui and gui:FindFirstChild("BoardLabel")
	if label then
		label.Text = buildLeaderboardText(entries)
	end
end

function HubWorldManager.sendLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local points = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, points)

	local leaderboard = LeaderboardManager.getTop(5)
	updateLeaderboardBoard(leaderboard)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = getPlayerRank(player),
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = inHub,
	})
end

function HubWorldManager.spawnInHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN)
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
	HubWorldManager.sendLobbyPayload(player, true)
end

function HubWorldManager.teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(findArenaSpawn())
	end
end

local function onEnterArena(player)
	HubWorldManager.teleportToArena(player)
	HubWorldManager.sendLobbyPayload(player, false)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		HubWorldManager.spawnInHub(player)
		HubWorldManager.sendLobbyPayload(player, true)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
	HubWorldManager.sendLobbyPayload(player, true)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(onEnterArena)
	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		remotes.OpenBeySelect:FireClient(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
