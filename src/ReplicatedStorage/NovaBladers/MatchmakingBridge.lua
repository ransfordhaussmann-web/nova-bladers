--[[
	MatchmakingBridge — load-order-safe API between HubManager and MatchmakingManager.
]]

local MatchmakingBridge = {}

local handlers = {}

function MatchmakingBridge.register(newHandlers)
	handlers = newHandlers
end

function MatchmakingBridge.joinQueue(player, modeId)
	if handlers.joinQueue then
		handlers.joinQueue(player, modeId)
	end
end

function MatchmakingBridge.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

function MatchmakingBridge.isArenaBusy()
	if handlers.isArenaBusy then
		return handlers.isArenaBusy()
	end
	return false
end

function MatchmakingBridge.onMatchStarted(players, modeId)
	if handlers.onMatchStarted then
		handlers.onMatchStarted(players, modeId)
	end
end

function MatchmakingBridge.onMatchEnded()
	if handlers.onMatchEnded then
		handlers.onMatchEnded()
	end
end

return MatchmakingBridge
