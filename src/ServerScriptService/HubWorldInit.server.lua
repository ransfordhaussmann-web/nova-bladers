local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local remotes = RemotesSetup.ensure()
HubWorldBuilder.build()

HubWorldManager.init(remotes, PlayerDataManager, LeaderboardManager)

remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.enterArena(player)
end)

remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	HubWorldManager.returnToHub(player)
end)

remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
	if HubWorldManager._inHub[player] then
		remotes.OpenBeySelect:FireClient(player)
	end
end)

for _, player in Players:GetPlayers() do
	HubWorldManager.onPlayerAdded(player)
end

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)
