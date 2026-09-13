--[[
	GameMatchState — tracks whether the arena is currently in use.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.isBusy()
	return GameMatchState.arenaBusy
end

function GameMatchState.setBusy(busy)
	GameMatchState.arenaBusy = busy == true
end

return GameMatchState
