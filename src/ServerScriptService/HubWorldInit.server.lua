local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)
local HubWorldManager = require(ServerScriptService.HubWorldManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	if not PlayerDataManager.get(player) then
		PlayerDataManager.load(player)
	end
	HubWorldManager.onPlayerAdded(player)
	HubWorldManager.pushLobbyState(player)
end
