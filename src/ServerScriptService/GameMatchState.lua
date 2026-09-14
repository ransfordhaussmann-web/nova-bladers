--[[
	GameMatchState — shared arena-busy flag between GameManager and MatchmakingService.
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
