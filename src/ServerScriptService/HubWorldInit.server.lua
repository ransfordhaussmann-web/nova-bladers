local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)

local hub = HubWorldManager.buildHubWorld()
HubWorldManager.connectZonePrompts(hub)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isPlayerInHub(player) then
		HubWorldManager.sendToArena(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.onPlayerAdded, player)
end
