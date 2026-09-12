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

function HubService.enterQueue(player, modeId)
	if handlers.enterQueue then
		handlers.enterQueue(player, modeId)
	end
end

function HubService.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function HubService.enterMatchQueue(player, modeId)
	if handlers.enterMatchQueue then
		handlers.enterMatchQueue(player, modeId)
	end
end

return HubService
