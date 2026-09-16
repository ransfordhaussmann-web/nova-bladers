--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

return MatchStateService
