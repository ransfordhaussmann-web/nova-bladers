local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)

local MatchmakingBridge = {}

local onMatchReadyCallback = nil
local onLeaveQueueCallback = nil

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingBridge.registerMatchReady(callback)
	onMatchReadyCallback = callback
end

function MatchmakingBridge.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingBridge.joinRecommended(player)
	return MatchmakingBridge.joinMode(player, getRecommendedModeId())
end

function MatchmakingBridge.joinMode(player, modeId)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingBridge.registerLeaveQueue(callback)
	onLeaveQueueCallback = callback
end

function MatchmakingBridge.leave(player)
	MatchmakingService.leaveQueue(player)
	if onLeaveQueueCallback then
		onLeaveQueueCallback(player)
	end
end

function MatchmakingBridge.getStatus(player)
	return MatchmakingService.getStatus(player)
end

function MatchmakingBridge.isArenaBusy()
	return MatchmakingService.isArenaBusy()
end

function MatchmakingBridge.onMatchEnded()
	MatchmakingService.setArenaBusy(false)
end

function MatchmakingBridge.init(onQueueUpdate)
	MatchmakingService.init({
		onQueueUpdate = onQueueUpdate,
		onMatchReady = function(players, modeId)
			if onMatchReadyCallback then
				onMatchReadyCallback(players, modeId)
			end
		end,
	})
end

function MatchmakingBridge.getModeLabel(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	return mode and mode.label or modeId
end

return MatchmakingBridge
