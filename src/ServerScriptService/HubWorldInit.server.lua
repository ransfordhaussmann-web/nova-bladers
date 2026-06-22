local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

HubWorldManager.connectRemotes()

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	HubWorldManager.onPlayerAdded(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		HubWorldManager.sendLobbyState(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
	HubWorldManager.onPlayerAdded(player)
	HubWorldManager.spawnInHub(player)
end
