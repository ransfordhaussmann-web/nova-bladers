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

function HubService.setArenaPhase(player)
	if handlers.setArenaPhase then
		handlers.setArenaPhase(player)
	end
end

function HubService.setArenaPhaseForPlayers(players)
	for _, player in players do
		HubService.setArenaPhase(player)
	end
end

return HubService
