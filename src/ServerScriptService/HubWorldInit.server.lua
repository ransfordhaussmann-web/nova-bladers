local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerReady(player)
end)
