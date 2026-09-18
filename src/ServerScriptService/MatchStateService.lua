--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {
	_busy = false,
}

function MatchStateService.isArenaBusy()
	return MatchStateService._busy
end

function MatchStateService.setArenaBusy(busy)
	MatchStateService._busy = busy == true
end

return MatchStateService
