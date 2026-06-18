local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

local function onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local function trySpawnInHub()
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			HubWorldManager.onPlayerReady(player)
		else
			player.CharacterAdded:Wait()
			task.wait(0.1)
			HubWorldManager.onPlayerReady(player)
		end
	end

	task.spawn(trySpawnInHub)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local data = PlayerDataManager.get(player)
	if data then
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	end
	PlayerDataManager.save(player)
end)
