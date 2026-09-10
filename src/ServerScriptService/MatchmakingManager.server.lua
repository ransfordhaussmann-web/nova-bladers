local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.setCallbacks({
	onQueueUpdate = function(player, status)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, status)
		end
	end,
	onMatchReady = function(payload)
		for _, player in payload.players do
			HubService.leaveHubForArena(player)
		end
		Bindables.MatchReady:Fire(payload)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
