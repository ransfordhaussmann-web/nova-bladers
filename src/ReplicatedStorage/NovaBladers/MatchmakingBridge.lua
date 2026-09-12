--[[
	MatchmakingBridge — load-order-safe API for HubManager to join/leave queues
	without requiring MatchmakingManager at require time.
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
	return false
end

function MatchmakingBridge.leaveQueue(player)
	if handlers.leaveQueue then
		return handlers.leaveQueue(player)
	end
	return false
end

function MatchmakingBridge.getPlayerQueue(player)
	if handlers.getPlayerQueue then
		return handlers.getPlayerQueue(player)
	end
	return nil
end

return MatchmakingBridge
