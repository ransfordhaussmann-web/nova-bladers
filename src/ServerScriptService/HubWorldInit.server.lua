local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ensureRemotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local remotes = ensureRemotes()

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
end

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

HubWorldManager.init(remotes)
