local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

RemotesSetup.ensure()
HubWorldBuilder.build(LeaderboardManager.getTop(5))

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerJoin(player)
end)

Players.PlayerRemoving:Connect(function(player)
	-- PlayerDataManager.save is handled elsewhere when GameManager exists
end)

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerJoin(player)
end

task.spawn(function()
	while true do
		task.wait(60)
		HubWorldBuilder.updateLeaderboard(LeaderboardManager.getTop(5))
	end
end)
