--[[
	MatchmakingBridge — load-order-safe API for HubManager to join/leave queues
	before MatchmakingManager has finished starting.
]]

local MatchmakingBridge = {}

local impl = nil

function MatchmakingBridge.register(service)
	impl = service
end

function MatchmakingBridge.joinQueue(player, modeId)
	if impl then
		return impl.joinQueue(player, modeId)
	end
	return false, "not_ready"
end

function MatchmakingBridge.leaveQueue(player)
	if impl then
		return impl.leaveQueue(player)
	end
end

function MatchmakingBridge.getQueueState(player)
	if impl then
		return impl.getQueueState(player)
	end
	return nil
end

return MatchmakingBridge
