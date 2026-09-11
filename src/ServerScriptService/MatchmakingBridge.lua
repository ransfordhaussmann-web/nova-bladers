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

return MatchmakingBridge
