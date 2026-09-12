local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
local service = MatchmakingService.ensure(Remotes, Bindables)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	service:joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	service:leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	service:setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	service:onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready — modes:", table.concat({ "training", "pvp", "ffa" }, ", "))

return service
