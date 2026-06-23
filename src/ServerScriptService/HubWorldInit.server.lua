local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local HubWorldManager = require(ServerScriptService.HubWorldManager)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local deps = {
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
}

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

HubWorldManager.init(deps)

-- Expose for future GameManager integration after matches
_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player, deps)
end

-- Refresh 3D leaderboard board periodically
task.spawn(function()
	while true do
		task.wait(60)
		HubWorldManager.refreshLeaderboard(deps)
	end
end)
