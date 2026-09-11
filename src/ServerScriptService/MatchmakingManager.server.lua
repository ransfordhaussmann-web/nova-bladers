local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerHandlers({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(modeId, playerList)
		MatchState.setBusy(true)
		for _, player in playerList do
			HubService.enterArena(player)
		end
		Bindables.MatchReady:Fire(modeId, playerList)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getActiveModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchState.setBusy(false)
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
