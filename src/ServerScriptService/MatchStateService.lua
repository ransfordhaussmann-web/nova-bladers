--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {
	_arenaBusy = false,
}

function MatchStateService.isArenaBusy()
	return MatchStateService._arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	MatchStateService._arenaBusy = busy == true
end

return MatchStateService
