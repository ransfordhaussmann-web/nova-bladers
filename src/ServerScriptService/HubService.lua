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

function HubService.markQueued(player, modeId)
	if handlers.markQueued then
		handlers.markQueued(player, modeId)
	end
end

function HubService.markHub(player)
	if handlers.markHub then
		handlers.markHub(player)
	end
end

function HubService.leaveHubForMatch(player)
	if handlers.leaveHubForMatch then
		handlers.leaveHubForMatch(player)
	end
end

return HubService
