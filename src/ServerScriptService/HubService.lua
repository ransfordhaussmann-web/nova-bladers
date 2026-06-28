local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubService = {}

local hubParts
local playersInHub = {}
local Remotes

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

local function updateHubLeaderboardScreen(entries)
	if not hubParts or not hubParts.leaderboardBody then
		return
	end
	hubParts.leaderboardBody.Text = formatLeaderboard(entries)
end

function HubService.sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	updateHubLeaderboardScreen(leaderboard)
	Remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = leaderboard,
		inHub = true,
	})
end

function HubService.broadcastLobbyReady()
	for _, player in Players:GetPlayers() do
		HubService.sendLobbyReady(player)
	end
end

function HubService.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not hubParts or not hubParts.spawn then
		return
	end
	root.CFrame = hubParts.spawn.CFrame + Vector3.new(0, 3, 0)
	playersInHub[player] = true
end

function HubService.leaveHub(player)
	playersInHub[player] = nil
end

function HubService.isInHub(player)
	return playersInHub[player] == true
end

local function signalArenaFromGate(player)
	if not playersInHub[player] then
		return
	end
	HubService.leaveHub(player)
	local events = ReplicatedStorage.NovaBladers:FindFirstChild("Events")
	local matchRequested = events and events:FindFirstChild("MatchRequested")
	if matchRequested and matchRequested:IsA("BindableEvent") then
		matchRequested:Fire(player)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			HubService.teleportToHub(player)
			HubService.sendLobbyReady(player)
		end)
	end)
	if player.Character then
		HubService.teleportToHub(player)
	end
	HubService.sendLobbyReady(player)
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
	HubService.broadcastLobbyReady()
end

function HubService.init()
	Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	hubParts = select(2, HubWorldBuilder.build())

	hubParts.arenaPrompt.Triggered:Connect(signalArenaFromGate)

	hubParts.beyPrompt.Triggered:Connect(function(player)
		local beySelect = Remotes:FindFirstChild("OpenBeySelect")
		if beySelect and beySelect:IsA("RemoteEvent") then
			beySelect:FireClient(player)
		end
	end)

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubService.leaveHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(player)
		HubService.broadcastLobbyReady()
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubService
