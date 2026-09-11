local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.register({
	onQueueUpdate = function(player, snapshot)
		Remotes.QueueUpdate:FireClient(player, snapshot)
	end,
	onMatchReady = function(modeId, playerList)
		Bindables.MatchReady:Fire(modeId, playerList)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.cleanupPlayer(player)
end)

print("[MatchmakingServer] Queue system ready")
