local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubBuilder = require(NovaBladers.HubBuilder)
local HubConfig = require(NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local hub = HubBuilder.build()

local function ensureRemotes()
	local remotesFolder = NovaBladers:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = NovaBladers
	end

	local function ensureRemote(name, className)
		local remote = remotesFolder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = remotesFolder
		end
		return remote
	end

	return {
		LobbyReady = ensureRemote("LobbyReady", "RemoteEvent"),
		EnterArena = ensureRemote("EnterArena", "RemoteEvent"),
		ReturnToHub = ensureRemote("ReturnToHub", "RemoteEvent"),
	}
end

local Remotes = ensureRemotes()
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function updateLeaderboardBoard(leaderboard, modeLabel)
	local boardFace = hub:FindFirstChild("LeaderboardFace")
	if boardFace then
		local gui = boardFace:FindFirstChild("LeaderboardGui")
		local label = gui and gui:FindFirstChild("LeaderboardLabel")
		if label then
			local lines = { "Top Spieler" }
			if modeLabel then
				table.insert(lines, modeLabel)
				table.insert(lines, "")
			end
			for _, entry in leaderboard do
				table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
			end
			if #leaderboard == 0 then
				table.insert(lines, "Noch keine Einträge")
			end
			label.Text = table.concat(lines, "\n")
		end
	end
end

local function updateStatsBoard(player, payload)
	local statsFace = hub:FindFirstChild("StatsFace")
	if not statsFace then
		return
	end
	local gui = statsFace:FindFirstChild("StatsGui")
	local label = gui and gui:FindFirstChild("StatsLabel")
	if not label then
		return
	end
	label.Text = string.format(
		"%s — Deine Stats\nWins: %d\nLosses: %d\nRank: %d\n\n%s",
		player.Name,
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or ""
	)
end

local function updateHubBoards(player, payload)
	updateStatsBoard(player, payload)
	updateLeaderboardBoard(payload.leaderboard, payload.modeLabel)
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
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
	inArena[player] = nil
end

local function sendLobbyReady(player)
	local payload = buildLobbyPayload(player)
	updateHubBoards(player, payload)
	Remotes.LobbyReady:FireClient(player, payload)
end

local function refreshAllLobbyClients()
	local leaderboard = LeaderboardManager.getTop(5)
	local modeLabel = getModeLabel()
	updateLeaderboardBoard(leaderboard, modeLabel)

	for _, player in Players:GetPlayers() do
		if not inArena[player] then
			local payload = buildLobbyPayload(player)
			updateStatsBoard(player, payload)
			Remotes.LobbyReady:FireClient(player, payload)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not inArena[player] then
				teleportToHub(player)
				sendLobbyReady(player)
			end
		end)
	end)

	if player.Character then
		teleportToHub(player)
	end
	sendLobbyReady(player)
end

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	inArena[player] = true
end)

Remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	teleportToHub(player)
	sendLobbyReady(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
	task.defer(refreshAllLobbyClients)
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
