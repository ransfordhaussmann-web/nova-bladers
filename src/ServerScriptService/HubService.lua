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

function HubService.notifyQueueChanged()
	if handlers.notifyQueueChanged then
		handlers.notifyQueueChanged()
	end
end

function HubService.preparePlayersForMatch(players)
	if handlers.preparePlayersForMatch then
		handlers.preparePlayersForMatch(players)
	end
end

return HubService
