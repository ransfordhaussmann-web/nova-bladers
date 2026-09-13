--[[
	GameMatchState — tracks whether the arena is occupied by an active match.
]]

local GameMatchState = {
	_busy = false,
}

function GameMatchState.isBusy()
	return GameMatchState._busy
end

function GameMatchState.setBusy(busy)
	GameMatchState._busy = busy == true
end

return GameMatchState
