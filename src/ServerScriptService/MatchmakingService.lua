--[[
	MatchmakingService — shared API between MatchmakingManager, HubManager, and GameManager.
]]

local MatchmakingService = {}

local handlers = {}

function MatchmakingService.register(newHandlers)
	for key, fn in newHandlers do
		handlers[key] = fn
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if handlers.joinQueue then
		return handlers.joinQueue(player, modeId)
	end
	return false
end

function MatchmakingService.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function MatchmakingService.getQueueMode(player)
	if handlers.getQueueMode then
		return handlers.getQueueMode(player)
	end
	return nil
end

function MatchmakingService.canStartMatch()
	if handlers.canStartMatch then
		return handlers.canStartMatch()
	end
	return true
end

function MatchmakingService.notifyMatchEnded()
	if handlers.onMatchEnded then
		handlers.onMatchEnded()
	end
end

return MatchmakingService
