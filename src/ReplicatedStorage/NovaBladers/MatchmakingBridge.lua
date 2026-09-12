--[[
	MatchmakingBridge — load-order-safe API between HubManager and MatchmakingManager.
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

function MatchmakingBridge.getQueueState(player)
	if handlers.getQueueState then
		return handlers.getQueueState(player)
	end
	return nil
end

function MatchmakingBridge.setArenaBusy(busy)
	if handlers.setArenaBusy then
		handlers.setArenaBusy(busy)
	end
end

return MatchmakingBridge
