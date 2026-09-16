--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
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
