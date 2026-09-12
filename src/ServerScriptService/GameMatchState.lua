--[[
	GameMatchState — tracks whether the arena is currently running a match.
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
