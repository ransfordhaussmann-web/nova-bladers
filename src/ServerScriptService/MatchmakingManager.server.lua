local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchmakingBridge = require(script.Parent.MatchmakingBridge)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.init(MatchmakingConfig, {
	onMatchReady = function(players, modeId)
		MatchmakingBridge.notifyMatchReady(players, modeId)
		Bindables.MatchReady:Fire({
			players = players,
			mode = modeId,
		})
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
	getQueueStatus = function(player)
		return MatchmakingService.getQueueStatus(player)
	end,
})

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and MatchmakingConfig.MODES[modeId] then
		return modeId
	end
	return MatchmakingConfig.DEFAULT_MODE
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, resolveModeId(modeId))
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

print("[MatchmakingManager] Queue system ready")
