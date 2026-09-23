--[[
	GameMatchState — tracks whether the arena is currently running a match.
]]

local GameMatchState = {
	busy = false,
}

function GameMatchState.isBusy()
	return GameMatchState.busy
end

function GameMatchState.setBusy(busy)
	GameMatchState.busy = busy == true
end

return GameMatchState
