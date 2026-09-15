--[[
	HubService — shared API for hub phase and post-match returns.
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

function HubService.markPlayerInQueue(player, modeId)
	if handlers.markPlayerInQueue then
		handlers.markPlayerInQueue(player, modeId)
	end
end

function HubService.markPlayersInArena(players)
	if handlers.markPlayersInArena then
		handlers.markPlayersInArena(players)
	end
end

return HubService
