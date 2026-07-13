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

function HubService.setPhaseArena(player)
	if handlers.setPhaseArena then
		handlers.setPhaseArena(player)
	end
end

function HubService.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

return HubService
