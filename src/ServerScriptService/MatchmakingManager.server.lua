local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

MatchmakingService.setCallbacks({
	onQueueUpdate = function(player, payload)
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end,
	onMatchReady = function(playerList, modeId)
		MatchReady:Fire(playerList, modeId)
	end,
})

MatchmakingBridge.register({
	joinQueue = function(player, modeId)
		return MatchmakingService.joinQueue(player, modeId)
	end,
	leaveQueue = function(player)
		return MatchmakingService.leaveQueue(player)
	end,
	getQueueStatus = function(player)
		return MatchmakingService.getQueueStatus(player)
	end,
})

QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[MatchmakingManager] Queue system ready — Training / PvP / FFA")
