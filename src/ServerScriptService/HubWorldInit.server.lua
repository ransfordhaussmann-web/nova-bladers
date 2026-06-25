local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()

local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
remotes:WaitForChild("HubInteract").OnServerEvent:Connect(function(player)
	HubWorldManager.onInteract(player)
end)
