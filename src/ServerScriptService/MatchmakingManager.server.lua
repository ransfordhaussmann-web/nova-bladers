local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local arenaIdle = true

Bindables.MatchEnded.Event:Connect(function()
	arenaIdle = true
end)

MatchmakingService.setCallbacks({
	canStartMatch = function()
		return arenaIdle
	end,
	onMatchReady = function(players, modeId)
		arenaIdle = false
		Bindables.MatchReady:Fire(players, modeId)
	end,
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
})

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

print("[MatchmakingManager] Queue system ready")
