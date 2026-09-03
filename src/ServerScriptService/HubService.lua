--[[
	HubService — shared API for GameManager and MatchmakingQueue.
]]

local HubService = {}

local handlers = {}

function HubService.register(newHandlers)
	handlers = newHandlers
end

function HubService.returnPlayerToHub(player)
	if handlers.returnToHub then
		handlers.returnToHub(player)
	end
end

function HubService.getPhase(player)
	if handlers.getPhase then
		return handlers.getPhase(player)
	end
	return nil
end

function HubService.notifyMatchStarting(players)
	if handlers.notifyMatchStarting then
		handlers.notifyMatchStarting(players)
	end
end

function HubService.canJoinQueue(player)
	if handlers.canJoinQueue then
		return handlers.canJoinQueue(player)
	end
	return true
end

return HubService
