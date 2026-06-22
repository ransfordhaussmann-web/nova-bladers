local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local HubWorldManager = require(script.Parent.HubWorldManager)

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
RemotesSetup.ensure()

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

HubWorldManager.init()
