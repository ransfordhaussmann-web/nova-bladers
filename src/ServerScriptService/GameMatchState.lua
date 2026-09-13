--[[
	GameMatchState — tracks whether the arena is currently running a match.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.isArenaBusy()
	return GameMatchState.arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	GameMatchState.arenaBusy = busy == true
end

return GameMatchState
