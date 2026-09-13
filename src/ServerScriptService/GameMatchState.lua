--[[
	GameMatchState — shared arena occupancy flag for MatchmakingService and GameManager.
]]

local GameMatchState = {
	_busy = false,
}

function GameMatchState.setBusy(busy)
	GameMatchState._busy = busy == true
end

function GameMatchState.isFree()
	return not GameMatchState._busy
end

return GameMatchState
