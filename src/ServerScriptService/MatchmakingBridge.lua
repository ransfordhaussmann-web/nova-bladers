--[[
	MatchmakingBridge — wires MatchmakingService to HubService and GameManager bindables.
]]

local MatchmakingBridge = {}

local handlers = {}

function MatchmakingBridge.register(newHandlers)
	handlers = newHandlers
end

function MatchmakingBridge.onMatchReady(modeId, players)
	if handlers.onMatchReady then
		handlers.onMatchReady(modeId, players)
	end
end

function MatchmakingBridge.onQueueUpdate(player, payload)
	if handlers.onQueueUpdate then
		handlers.onQueueUpdate(player, payload)
	end
end

function MatchmakingBridge.onQueueLeft(player)
	if handlers.onQueueLeft then
		handlers.onQueueLeft(player)
	end
end

return MatchmakingBridge
