--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallback = nil

function MatchStateService.setArenaBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy
	if wasBusy and not busy and onFreedCallback then
		onFreedCallback()
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFreed(callback)
	onFreedCallback = callback
end

return MatchStateService
