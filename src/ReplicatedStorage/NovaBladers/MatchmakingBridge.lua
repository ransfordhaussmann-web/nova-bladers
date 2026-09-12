--[[
	MatchmakingBridge — decouples HubManager from MatchmakingService load order.
]]

local MatchmakingBridge = {}

local handlers = {}
local pendingJoins = {}

function MatchmakingBridge.register(newHandlers)
	handlers = newHandlers
	for _, request in pendingJoins do
		if request.player.Parent then
			handlers.joinQueue(request.player, request.modeId)
		end
	end
	table.clear(pendingJoins)
end

function MatchmakingBridge.joinQueue(player, modeId)
	if handlers.joinQueue then
		return handlers.joinQueue(player, modeId)
	end
	table.insert(pendingJoins, { player = player, modeId = modeId })
	return true
end

function MatchmakingBridge.leaveQueue(player)
	if handlers.leaveQueue then
		handlers.leaveQueue(player)
	end
end

return MatchmakingBridge
