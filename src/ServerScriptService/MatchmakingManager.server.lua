local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

MatchmakingService.init({
	onMatchReady = function(players, modeId)
		for _, player in players do
			HubService.enterArena(player)
		end
		MatchReady:Fire(players, modeId)
	end,
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
})

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		MatchmakingService.leaveQueue(player)
	end,
	getQueueState = function(player)
		return MatchmakingService.getQueueState(player)
	end,
	setArenaBusy = function(busy)
		MatchmakingService.setArenaBusy(busy)
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

MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready")
