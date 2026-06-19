local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(ServerScriptService.HubWorldManager)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local Players = game:GetService("Players")

RemotesSetup.ensure()
HubWorldBuilder.build()
HubWorldManager.bindRemotes()

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end
