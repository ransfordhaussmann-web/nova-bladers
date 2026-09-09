--[[
	HubService — shared API for GameManager to return players to the 3D hub after matches.
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

function HubService.enterQueue(player)
	if handlers.enterQueue then
		handlers.enterQueue(player)
	end
end

function HubService.enterArenaFromQueue(player)
	if handlers.enterArenaFromQueue then
		handlers.enterArenaFromQueue(player)
	end
end

return HubService
