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

function HubService.getPreferredMode(player)
	if handlers.getPreferredMode then
		return handlers.getPreferredMode(player)
	end
	return nil
end

function HubService.setPreferredMode(player, modeId)
	if handlers.setPreferredMode then
		handlers.setPreferredMode(player, modeId)
	end
end

return HubService
