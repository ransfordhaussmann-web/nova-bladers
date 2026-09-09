--[[
	MatchCoordinator — shared bridge between GameManager and MatchmakingManager.
]]

local MatchCoordinator = {}

local handlers = {}

function MatchCoordinator.register(newHandlers)
	for key, handler in newHandlers do
		handlers[key] = handler
	end
end

function MatchCoordinator.isBusy()
	if handlers.isBusy then
		return handlers.isBusy()
	end
	return false
end

function MatchCoordinator.beginMatch(players)
	if handlers.beginMatch then
		handlers.beginMatch(players)
	end
end

function MatchCoordinator.notifyMatchEnded()
	if handlers.onMatchEnded then
		handlers.onMatchEnded()
	end
end

return MatchCoordinator
