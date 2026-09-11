local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.register({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(matchInfo)
		Bindables.MatchReady:Fire(matchInfo)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	local modeId = MatchmakingService.getRecommendedMode()
	MatchmakingService.joinQueue(player, modeId)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

print("[MatchmakingServer] Queue system ready")
