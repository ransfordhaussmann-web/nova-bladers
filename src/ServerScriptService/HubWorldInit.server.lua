local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

RemotesSetup.ensure()
HubWorldBuilder.build()
HubWorldManager.init()

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerReady(player)
end

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerReady(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)
