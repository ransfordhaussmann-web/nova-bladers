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

function HubService.onPlayerQueued(player, modeId)
	if handlers.onPlayerQueued then
		handlers.onPlayerQueued(player, modeId)
	end
end

function HubService.onPlayerLeftQueue(player)
	if handlers.onPlayerLeftQueue then
		handlers.onPlayerLeftQueue(player)
	end
end

function HubService.onMatchStarting(players)
	if handlers.onMatchStarting then
		handlers.onMatchStarting(players)
	end
end

return HubService
