--[[
	MatchStateService — tracks whether the arena is busy so queues can show a pending state.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

return MatchStateService
