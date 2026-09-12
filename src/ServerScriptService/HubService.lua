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

function HubService.prepareForArena(player)
	if handlers.prepareForArena then
		handlers.prepareForArena(player)
	end
end

function HubService.getRecommendedMode()
	if handlers.getRecommendedMode then
		return handlers.getRecommendedMode()
	end
	return "training"
end

function HubService.joinMatchmaking(player, modeId)
	if handlers.joinMatchmaking then
		handlers.joinMatchmaking(player, modeId)
	end
end

return HubService
