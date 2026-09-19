--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {
	_busy = false,
}

function MatchStateService.setBusy(busy)
	MatchStateService._busy = busy == true
end

function MatchStateService.isArenaBusy()
	return MatchStateService._busy
end

return MatchStateService
