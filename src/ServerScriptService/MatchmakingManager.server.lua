local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

print("[MatchmakingManager] Queue system ready")
