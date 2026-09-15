--[[
	HubService — shared API for hub phase transitions and match returns.
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

function HubService.enterQueue(player, modeId)
	if handlers.enterQueue then
		handlers.enterQueue(player, modeId)
	end
end

function HubService.setQueuePending(player, modeId)
	if handlers.setQueuePending then
		handlers.setQueuePending(player, modeId)
	end
end

function HubService.enterMatch(player, modeId)
	if handlers.enterMatch then
		handlers.enterMatch(player, modeId)
	end
end

return HubService
