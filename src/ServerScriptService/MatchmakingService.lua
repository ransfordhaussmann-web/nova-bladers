--[[
	MatchmakingService — shared API between MatchmakingManager and GameManager.
]]

local MatchmakingService = {}

local arenaBusy = false
local onArenaFreed = nil

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy and onArenaFreed then
		onArenaFreed()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.onArenaFreed(callback)
	onArenaFreed = callback
end

return MatchmakingService
