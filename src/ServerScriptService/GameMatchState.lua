--[[
	GameMatchState — tracks whether the arena is currently running a match.
]]

local GameMatchState = {}

local busy = false

function GameMatchState.isBusy()
	return busy
end

function GameMatchState.setBusy()
	busy = true
end

function GameMatchState.setFree()
	busy = false
end

return GameMatchState
