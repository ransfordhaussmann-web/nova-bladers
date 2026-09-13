--[[
	GameMatchState — shared arena-busy flag for MatchmakingService and GameManager.
]]

local GameMatchState = {}

local arenaBusy = false

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy == true
end

return GameMatchState
