local ServerScriptService = game:GetService("ServerScriptService")

local HubWorldManager = require(ServerScriptService.HubWorldManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

HubWorldManager.configure({
	leaderboardManager = LeaderboardManager,
	playerDataManager = PlayerDataManager,
})

HubWorldManager.start()
