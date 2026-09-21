--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {
	arenaBusy = false,
}

function MatchStateService.isArenaBusy()
	return MatchStateService.arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	MatchStateService.arenaBusy = busy == true
end

return MatchStateService
