local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(Remotes, Bindables.StartMatch)

Remotes.MatchmakingJoin.OnServerEvent:Connect(function(player, mode)
	if typeof(mode) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, mode)
end)

Remotes.MatchmakingLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.removeFromQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removeFromQueue(player)
end)

print("[MatchmakingManager] Queue ready — Training / 1v1 / FFA")
