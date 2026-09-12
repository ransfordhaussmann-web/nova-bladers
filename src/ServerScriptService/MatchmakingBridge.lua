--[[
	MatchmakingBridge — load-order-safe API between HubManager and MatchmakingManager.
]]

local MatchmakingBridge = {}

local handlers = {}
local hubMatchReadyCallback

function MatchmakingBridge.register(newHandlers)
	handlers = newHandlers
end

function MatchmakingBridge.joinQueue(player, modeId)
	if handlers.joinQueue then
		handlers.joinQueue(player, modeId)
	end
end

function MatchmakingBridge.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function MatchmakingBridge.getQueueStatus(player)
	if handlers.getQueueStatus then
		return handlers.getQueueStatus(player)
	end
	return nil
end

function MatchmakingBridge.onMatchReady(callback)
	hubMatchReadyCallback = callback
end

function MatchmakingBridge.notifyMatchReady(players, modeId)
	if hubMatchReadyCallback then
		hubMatchReadyCallback(players, modeId)
	end
end

return MatchmakingBridge
