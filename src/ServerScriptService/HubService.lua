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

function HubService.enterHub(player)
	if handlers.enterHub then
		handlers.enterHub(player)
	end
end

function HubService.enterQueue(player, modeId)
	if handlers.enterQueue then
		handlers.enterQueue(player, modeId)
	end
end

function HubService.enterArena(player)
	if handlers.enterArena then
		handlers.enterArena(player)
	end
end

function HubService.getPhase(player)
	if handlers.getPhase then
		return handlers.getPhase(player)
	end
	return nil
end

return HubService
