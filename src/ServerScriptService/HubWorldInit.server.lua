local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local HubWorldManager = require(ServerScriptService.HubWorldManager)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.onPlayerAdded, player)
end
