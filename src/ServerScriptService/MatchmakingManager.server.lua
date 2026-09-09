local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(players, modeId)
		Bindables.MatchReady:Fire(players, modeId)
	end,
})

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
