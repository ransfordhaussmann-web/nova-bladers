--[[
	GameMatchState — shared flag so MatchmakingService knows when the arena is occupied.
]]

local GameMatchState = {
	_busy = false,
}

function GameMatchState.setBusy(busy)
	GameMatchState._busy = busy == true
end

function GameMatchState.isBusy()
	return GameMatchState._busy
end

return GameMatchState
