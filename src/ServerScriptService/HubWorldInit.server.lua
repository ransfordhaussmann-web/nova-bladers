local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)
local HubWorldManager = require(ServerScriptService.HubWorldManager)

local function onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

HubWorldManager.init({
	playerDataManager = PlayerDataManager,
	leaderboardManager = LeaderboardManager,
})
