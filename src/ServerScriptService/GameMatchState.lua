--[[
	GameMatchState — tracks whether the arena is currently running a match.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.isArenaBusy()
	return GameMatchState.arenaBusy
end

function GameMatchState.markArenaBusy()
	GameMatchState.arenaBusy = true
end

function GameMatchState.markArenaFree()
	GameMatchState.arenaBusy = false
end

return GameMatchState
