local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

HubWorldManager.init()

local function sendLobbyToPlayer(player: Player)
	local data = PlayerDataManager.get(player)
	local leaderboard = LeaderboardManager.getTop(5)
	local payload = HubWorldManager.buildLobbyPayload(player, data, leaderboard)
	HubWorldManager.sendLobbyReady(player, payload)
end

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)

	local rankPoints = PlayerDataManager.getRankPoints(PlayerDataManager.get(player))
	LeaderboardManager.submit(player, rankPoints)

	task.defer(sendLobbyToPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	task.defer(sendLobbyToPlayer, player)
end
