local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)

local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

HubWorldManager.buildHub()
HubWorldManager.connectZonePrompts()

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.onPlayerAdded, player)
end

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.enterArena(player)
end)
