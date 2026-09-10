local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.setListeners({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(modeId, playerList)
		Bindables.MatchReady:Fire(modeId, playerList)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedMode()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchStateService.setArenaBusy(false)
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
