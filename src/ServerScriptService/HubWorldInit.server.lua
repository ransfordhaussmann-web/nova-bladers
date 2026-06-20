local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

-- Remotes vor Client-Scripts bereitstellen
require(ReplicatedStorage.NovaBladers.RemotesSetup).ensure()

HubWorldManager.init()

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
end)
for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)
