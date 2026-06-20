local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubData
local playerInHub = {}

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then return nil end
	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	for _, child in arena:GetDescendants() do
		if child:IsA("SpawnLocation") or child.Name == "Spawn" then
			return child
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	else
		return string.format("Modus: FFA (%d Spieler)", playerCount)
	end
end

local function formatLeaderboard(entries)
	local lines = { "🏆 Top Spieler:" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function updateLeaderboardBoard()
	if not hubData or not hubData.leaderboardLabel then return end
	local entries = LeaderboardManager.getTop(5)
	hubData.leaderboardLabel.Text = formatLeaderboard(entries)
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	})
end

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hubData then return end

	hrp.CFrame = hubData.spawn.CFrame + Vector3.new(0, 3, 0)
	playerInHub[player] = true
end

function HubWorldManager.returnToHub(player)
	teleportToHub(player)
	sendLobbyReady(player)
end

local function enterArena(player)
	playerInHub[player] = false
	remotes.HubZoneHint:FireClient(player, { visible = false })

	local spawn = findArenaSpawn()
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if spawn then
		hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	else
		warn("[HubWorldManager] Kein Arena-Spawn gefunden — Fallback-Position")
		hrp.CFrame = CFrame.new(0, 5, 0)
	end
end

local function openBeySelect(player)
	remotes.OpenBeySelect:FireClient(player)
end

local ZONE_ACTIONS = {
	enterArena = enterArena,
	openBeySelect = openBeySelect,
	showLeaderboard = function(player)
		local entries = LeaderboardManager.getTop(5)
		remotes.HubZoneHint:FireClient(player, {
			visible = true,
			zoneName = "Ruhmeshalle",
			hint = formatLeaderboard(entries),
			duration = 5,
		})
	end,
}

local function connectZone(zoneId, zoneInfo)
	local action = zoneInfo.config.action
	local handler = ZONE_ACTIONS[action]
	if not handler then return end

	zoneInfo.trigger:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(player)
		if not playerInHub[player] then return end
		handler(player)
	end)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if playerInHub[player] then
			teleportToHub(player)
			sendLobbyReady(player)
		end
	end)

	playerInHub[player] = true

	if player.Character then
		teleportToHub(player)
		sendLobbyReady(player)
	end
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerInHub[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubData = HubWorldBuilder.build()

	for zoneId, zoneInfo in hubData.zones do
		connectZone(zoneId, zoneInfo)
	end

	updateLeaderboardBoard()
	task.spawn(function()
		while true do
			task.wait(HubConfig.LEADERBOARD_REFRESH)
			updateLeaderboardBoard()
		end
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playerInHub[player] then
			enterArena(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
