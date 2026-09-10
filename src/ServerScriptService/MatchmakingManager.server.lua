local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

task.defer(function()
	MatchmakingService.registerHandlers({
		onMatchReady = function(payload)
			for _, player in payload.players do
				HubService.enterArena(player)
			end
			Bindables.MatchReady:Fire(payload)
		end,
		onQueueUpdate = function(player, payload)
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end,
	})
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
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
