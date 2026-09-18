--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallback = nil

function MatchStateService.setArenaBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy
	if wasBusy and not busy and onArenaFreeCallback then
		onArenaFreeCallback()
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	onArenaFreeCallback = callback
end

return MatchStateService
