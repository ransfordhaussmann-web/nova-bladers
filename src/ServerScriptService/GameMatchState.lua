--[[
	GameMatchState — tracks whether the arena is currently running a match.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.setArenaBusy(busy)
	GameMatchState.arenaBusy = busy
end

function GameMatchState.isArenaBusy()
	return GameMatchState.arenaBusy
end

return GameMatchState
