--[[
	HubService — shared API for GameManager to return players to the 3D hub after matches.
]]

local HubService = {}

local handlers = {}

function HubService.register(newHandlers)
	for key, fn in newHandlers do
		handlers[key] = fn
	end
end

function HubService.returnPlayerToHub(player)
	if handlers.returnToHub then
		handlers.returnToHub(player)
	end
end

function HubService.canJoinQueue()
	if handlers.canJoinQueue then
		return handlers.canJoinQueue()
	end
	return true
end

function HubService.getPhase(player)
	if handlers.getPhase then
		return handlers.getPhase(player)
	end
	return nil
end

return HubService
