--[[
	MatchmakingService — shared API for HubManager and GameManager.
]]

local MatchmakingService = {}

local handlers = {}

function MatchmakingService.register(newHandlers)
	handlers = newHandlers
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

function MatchmakingService.getQueueState(player)
	if handlers.getQueueState then
		return handlers.getQueueState(player)
	end
	return nil
end

function MatchmakingService.setArenaBusy(busy)
	if handlers.setArenaBusy then
		handlers.setArenaBusy(busy)
	end
end

function MatchmakingService.requeuePlayers(playerList, modeId)
	if handlers.requeuePlayers then
		handlers.requeuePlayers(playerList, modeId)
	end
end

return MatchmakingService
