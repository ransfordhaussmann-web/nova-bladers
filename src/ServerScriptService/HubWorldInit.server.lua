local Players = game:GetService("Players")

local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)
