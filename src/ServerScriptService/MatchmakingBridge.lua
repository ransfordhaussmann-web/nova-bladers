--[[
	MatchmakingBridge — load-order-safe API for HubManager → MatchmakingService.
	MatchmakingManager registers handlers after both modules are loaded.
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
	return false, "Matchmaking noch nicht bereit"
end

function MatchmakingBridge.leaveQueue(player)
	if handlers.leaveQueue then
		return handlers.leaveQueue(player)
	end
	return false
end

function MatchmakingBridge.getQueueState(player)
	if handlers.getQueueState then
		return handlers.getQueueState(player)
	end
	return nil
end

return MatchmakingBridge
