--[[
	HubService — shared API for GameManager and MatchmakingService.
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

function HubService.markArena(player, modeId)
	if handlers.markArena then
		handlers.markArena(player, modeId)
	end
end

function HubService.markHub(player)
	if handlers.markHub then
		handlers.markHub(player)
	end
end

return HubService
