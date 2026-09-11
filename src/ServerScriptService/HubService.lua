--[[
	HubService — shared API for GameManager to return players to the 3D hub after matches.
]]

local HubService = {}

local handlers = {}
local matchmakingHandlers = {}

function HubService.register(newHandlers)
	handlers = newHandlers
end

function HubService.registerMatchmaking(newHandlers)
	matchmakingHandlers = newHandlers
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

function HubService.setPlayerPhase(player, phase)
	if handlers.setPhase then
		handlers.setPhase(player, phase)
	end
end

function HubService.requestJoinQueue(player, modeId)
	if matchmakingHandlers.joinQueue then
		return matchmakingHandlers.joinQueue(player, modeId)
	end
	return false, "Matchmaking nicht bereit"
end

function HubService.requestLeaveQueue(player)
	if matchmakingHandlers.leaveQueue then
		return matchmakingHandlers.leaveQueue(player)
	end
	return false
end

return HubService
