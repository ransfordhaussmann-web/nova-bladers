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

function HubService.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function HubService.joinQueue(player, modeId)
	if handlers.joinQueue then
		return handlers.joinQueue(player, modeId)
	end
	return false
end

function HubService.joinQuickMatch(player)
	if handlers.joinQuickMatch then
		return handlers.joinQuickMatch(player)
	end
	return false
end

function HubService.isInQueue(player)
	if handlers.isInQueue then
		return handlers.isInQueue(player)
	end
	return false
end

function HubService.setMatchPhase(player, modeId)
	if handlers.setMatchPhase then
		handlers.setMatchPhase(player, modeId)
	end
end

return HubService
