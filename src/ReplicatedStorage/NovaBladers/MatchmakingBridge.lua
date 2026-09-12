--[[
	MatchmakingBridge — load-order-safe API for HubManager to join/leave queues
	without requiring MatchmakingManager directly.
]]

local MatchmakingBridge = {}

local handlers = {}

function MatchmakingBridge.register(newHandlers)
	handlers = newHandlers or {}
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

return MatchmakingBridge
