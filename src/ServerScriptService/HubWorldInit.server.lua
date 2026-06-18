local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)

RemotesSetup.ensure()
local hub = HubWorldBuilder.build()
HubWorldManager.setHubModel(hub)
HubWorldManager.bindRemotes()

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local PlayerDataManager = require(script.Parent.PlayerDataManager)
	PlayerDataManager.save(player)
end)
