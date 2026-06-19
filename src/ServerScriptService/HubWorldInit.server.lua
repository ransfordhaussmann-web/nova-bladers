local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(ServerScriptService.HubWorldManager)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local remotes = RemotesSetup.ensure()
HubWorldBuilder.build()
HubWorldManager.init(remotes, PlayerDataManager, LeaderboardManager)

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerReady(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.onPlayerReady, player)
end

remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.enterArena(player)
end)

remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	HubWorldManager.returnToHub(player)
end)

remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
	if not HubWorldManager.isInHub(player) then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerDataManager.save(player)
	end
end)
