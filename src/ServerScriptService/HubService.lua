--[[
	HubService — shared API for GameManager to return players to the 3D hub after matches.
]]

local HubService = {}

local handlers = {}
local matchmaking = {}

function HubService.register(newHandlers)
	handlers = newHandlers
end

function HubService.registerMatchmaking(newMatchmaking)
	matchmaking = newMatchmaking
end

function HubService.returnPlayerToHub(player)
	if handlers.returnToHub then
		handlers.returnToHub(player)
	end
end

function HubService.leaveHubForArena(player)
	if handlers.leaveHubForArena then
		handlers.leaveHubForArena(player)
	end
end

function HubService.getPhase(player)
	if handlers.getPhase then
		return handlers.getPhase(player)
	end
	return nil
end

function HubService.joinQueue(player, modeId)
	if matchmaking.joinQueue then
		matchmaking.joinQueue(player, modeId)
	end
end

function HubService.leaveQueue(player)
	if matchmaking.leaveQueue then
		matchmaking.leaveQueue(player)
	end
end

return HubService
