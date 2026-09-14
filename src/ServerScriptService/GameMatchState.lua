--[[
	GameMatchState — tracks whether the arena is currently occupied by a match.
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
