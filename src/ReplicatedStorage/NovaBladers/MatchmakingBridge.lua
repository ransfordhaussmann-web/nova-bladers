--[[
	MatchmakingBridge — thin API for HubManager and other server scripts.
]]

local MatchmakingBridge = {}

local service = nil

function MatchmakingBridge.register(matchmakingService)
	service = matchmakingService
end

function MatchmakingBridge.joinQueue(player, modeId)
	if service then
		service:joinQueue(player, modeId)
	end
end

function MatchmakingBridge.leaveQueue(player)
	if service then
		service:removeFromQueue(player)
	end
end

function MatchmakingBridge.getStatus(player)
	if service then
		return service:getPlayerStatus(player)
	end
	return nil
end

return MatchmakingBridge
