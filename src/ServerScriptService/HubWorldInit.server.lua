local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = require(script.Parent.HubWorldManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local remotes = NovaBladers:WaitForChild("Remotes")

HubWorldManager.init()

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.onPlayerAdded, player)
end

remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end)

local returnToHub = remotes:FindFirstChild("ReturnToHub")
if returnToHub then
	returnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)
end
