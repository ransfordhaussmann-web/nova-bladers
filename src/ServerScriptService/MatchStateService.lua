--[[
	Tracks whether the arena is running a match (matchmaking waits when busy).
]]

local MatchStateService = {
	_busy = false,
}

function MatchStateService.setArenaBusy(busy)
	MatchStateService._busy = busy == true
end

function MatchStateService.isArenaBusy()
	return MatchStateService._busy
end

return MatchStateService
