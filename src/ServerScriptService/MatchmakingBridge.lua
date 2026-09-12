--[[
	MatchmakingBridge — load-order-safe API for HubManager and GameManager.
]]

local MatchmakingBridge = {}

local handlers = {}

function MatchmakingBridge.register(newHandlers)
	handlers = newHandlers
end

function MatchmakingBridge.joinQueue(player, modeId)
	if handlers.joinQueue then
		return handlers.joinQueue(player, modeId)
	end
	return false, "not_ready"
end

function MatchmakingBridge.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function MatchmakingBridge.getQueueState(player)
	if handlers.getQueueState then
		return handlers.getQueueState(player)
	end
	return { inQueue = false }
end

function MatchmakingBridge.setArenaBusy(busy)
	if handlers.setArenaBusy then
		handlers.setArenaBusy(busy)
	end
end

return MatchmakingBridge
