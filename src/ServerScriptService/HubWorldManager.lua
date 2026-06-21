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
local playerInHub = {}

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

local function updateLeaderboardBoard()
	if not hubFolder then return end
	local boardFolder = hubFolder:FindFirstChild("LeaderboardBoard")
	if not boardFolder then return end
	local board = boardFolder:FindFirstChild("Board")
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local label = gui:FindFirstChild("BoardText")
	if not label then return end

	local lines = { "🏆 Top Spieler" }
	for _, entry in LeaderboardManager.getTop(5) do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 1 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	updateLeaderboardBoard()
end

function HubWorldManager.spawnInHub(player)
	playerInHub[player] = true
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
		end
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	playerInHub[player] = true
	local character = player.Character
	if not character then return end
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.isInHub(player)
	return playerInHub[player] == true
end

function HubWorldManager.teleportToArena(player)
	playerInHub[player] = false
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = HubWorldBuilder.getArenaSpawnCFrame()
	end
end

function HubWorldManager.refreshAll()
	updateLeaderboardBoard()
	for _, player in Players:GetPlayers() do
		if playerInHub[player] then
			remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if playerInHub[player] ~= false then
			HubWorldManager.spawnInHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playerInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.connectRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not playerInHub[player] then return end
		HubWorldManager.teleportToArena(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if not playerInHub[player] then return end
		remotes.OpenBeySelect:FireClient(player)
	end)
end

return HubWorldManager
