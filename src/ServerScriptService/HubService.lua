--[[
	HubService — shared API for GameManager and MatchmakingService to manage hub phases.
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
	HubService.returnPlayerToHub(player)
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

function HubService.getQueueStatus(player)
	if handlers.getQueueStatus then
		return handlers.getQueueStatus(player)
	end
	return nil
end

function HubService.broadcastLobby()
	if handlers.broadcastLobby then
		handlers.broadcastLobby()
	end
end

return HubService
