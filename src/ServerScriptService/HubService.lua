--[[
	HubService — shared API for GameManager to return players to the 3D hub after matches.
]]

local HubService = {}

local handlers = {}

function HubService.register(newHandlers)
	for key, handler in newHandlers do
		handlers[key] = handler
	end
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

function HubService.leaveHubForArena(player)
	if handlers.leaveHubForArena then
		handlers.leaveHubForArena(player)
	end
end

return HubService
