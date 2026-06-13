local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(script.Parent.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)

RemotesSetup.ensure()
HubWorldManager.init()

local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.enterArena(player)
end)

remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	HubWorldManager.returnToHub(player)
end)

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end
