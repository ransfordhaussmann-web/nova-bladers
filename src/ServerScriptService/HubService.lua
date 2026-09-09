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

function HubService.enterQueue(player, modeId)
	if handlers.enterQueue then
		handlers.enterQueue(player, modeId)
	end
end

function HubService.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function HubService.enterArena(player)
	if handlers.enterArena then
		handlers.enterArena(player)
	end
end

function HubService.requestJoinQueue(player, modeId)
	if handlers.requestJoinQueue then
		handlers.requestJoinQueue(player, modeId)
	end
end

return HubService
