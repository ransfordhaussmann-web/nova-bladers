local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ensureRemotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)
ensureRemotes()

local HubWorldManager = require(ServerScriptService.HubWorldManager)

HubWorldManager.init()

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end
