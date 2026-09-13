--[[
	GameMatchState — shared arena occupancy flag for MatchmakingService and GameManager.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.setArenaBusy(busy)
	GameMatchState.arenaBusy = busy == true
end

function GameMatchState.isArenaBusy()
	return GameMatchState.arenaBusy
end

return GameMatchState
