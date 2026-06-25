local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubManager = {}

local remotes = nil
local playersInHub = {}

local function getRemotes()
	if remotes then
		return remotes
	end
	local folder = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
	remotes = {
		LobbyReady = folder:WaitForChild("LobbyReady"),
		EnterArena = folder:WaitForChild("EnterArena"),
	}
	return remotes
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return HubConfig.LABELS.ModeTraining
	elseif playerCount == 2 then
		return HubConfig.LABELS.ModePvP
	end
	return string.format(HubConfig.LABELS.ModeFFA, playerCount)
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

function HubManager.updateBoards(player, payload)
	local statsLabel = HubWorldBuilder.getBoard("StatsBoard")
	if statsLabel then
		statsLabel.Text = string.format(
			"📊 Deine Stats\n\nWins: %d\nLosses: %d\nRang: %d\n\n%s",
			payload.wins,
			payload.losses,
			payload.rank,
			payload.modeLabel or ""
		)
	end

	local leaderboardLabel = HubWorldBuilder.getBoard("Leaderboard")
	if leaderboardLabel then
		local lines = {"🏆 Top Spieler", ""}
		if payload.leaderboard then
			for _, entry in payload.leaderboard do
				table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
			end
			if #payload.leaderboard == 0 then
				table.insert(lines, "Noch keine Einträge")
			end
		end
		leaderboardLabel.Text = table.concat(lines, "\n")
	end
end

function HubManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubManager.sendLobbyReady(player)
	local payload = HubManager.buildLobbyPayload(player)
	HubManager.updateBoards(player, payload)
	getRemotes().LobbyReady:FireClient(player, payload)
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.SPAWN)
	playersInHub[player] = true
end

function HubManager.isInHub(player)
	return playersInHub[player] == true
end

function HubManager.enterArena(player)
	if not HubManager.isInHub(player) then
		return
	end
	playersInHub[player] = nil
	local bindable = ReplicatedStorage:FindFirstChild("NovaBladers")
	if bindable then
		local signal = bindable:FindFirstChild("HubEnterArena")
		if signal and signal:IsA("BindableEvent") then
			signal:Fire(player)
		end
	end
end

function HubManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		HubManager.teleportToHub(player)
		HubManager.sendLobbyReady(player)
	end)

	if player.Character then
		HubManager.teleportToHub(player)
	end
	HubManager.sendLobbyReady(player)
end

function HubManager.onPlayerRemoving(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end

function HubManager.refreshAll()
	for _, player in Players:GetPlayers() do
		if HubManager.isInHub(player) then
			HubManager.sendLobbyReady(player)
		end
	end
end

function HubManager.init()
	HubWorldBuilder.build()
	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		HubManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(HubManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(HubManager.onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(function()
		task.defer(HubManager.refreshAll)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(HubManager.refreshAll)
	end)
end

return HubManager
