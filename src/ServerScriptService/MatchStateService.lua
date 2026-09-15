--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {
	_busy = false,
}

function MatchStateService.isArenaBusy()
	return MatchStateService._busy
end

function MatchStateService.setBusy()
	MatchStateService._busy = true
end

function MatchStateService.setIdle()
	MatchStateService._busy = false
end

return MatchStateService
