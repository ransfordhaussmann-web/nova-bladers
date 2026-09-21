--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
end

return MatchStateService
