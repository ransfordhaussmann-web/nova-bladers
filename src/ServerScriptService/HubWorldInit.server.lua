local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

RemotesSetup.getRemotes()

HubWorldManager.init({
	playerDataManager = PlayerDataManager,
	leaderboardManager = LeaderboardManager,
})
