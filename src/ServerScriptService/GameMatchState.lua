--[[
	GameMatchState — tracks whether the arena is occupied by an active match.
]]

local GameMatchState = {
	busy = false,
}

function GameMatchState.isBusy()
	return GameMatchState.busy
end

function GameMatchState.setBusy(value)
	GameMatchState.busy = value == true
end

return GameMatchState
