local Players = game:GetService("Players")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)
