--[[
	GameMatchState — tracks whether the arena is occupied by an active match.
]]

local GameMatchState = {
	busy = false,
}

function GameMatchState.setBusy(value)
	GameMatchState.busy = value == true
end

function GameMatchState.isBusy()
	return GameMatchState.busy
end

return GameMatchState
