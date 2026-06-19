local Players = game:GetService("Players")

local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.spawnPlayerInHub(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.spawnPlayerInHub, player)
end
