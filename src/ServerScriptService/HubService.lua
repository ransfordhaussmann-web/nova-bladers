--[[
	HubService — shared API for hub phase, matchmaking queue, and post-match return.
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

function HubService.setQueuePhase(player, modeId, phase)
	if handlers.setQueuePhase then
		handlers.setQueuePhase(player, modeId, phase)
	end
end

return HubService
