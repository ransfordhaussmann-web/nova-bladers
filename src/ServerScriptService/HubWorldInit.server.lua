local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)
local HubWorldManager = require(ServerScriptService.HubWorldManager)

HubWorldManager.init({
	playerDataManager = PlayerDataManager,
	leaderboardManager = LeaderboardManager,
})
