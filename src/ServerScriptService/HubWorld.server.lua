local HubManager = require(script.Parent.HubManager)

HubManager.setup()

local Players = game:GetService("Players")
for _, player in Players:GetPlayers() do
	HubManager.setupPlayer(player)
end
Players.PlayerAdded:Connect(function(player)
	HubManager.setupPlayer(player)
end)
