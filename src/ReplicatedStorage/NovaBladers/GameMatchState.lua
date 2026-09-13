--[[
	GameMatchState — shared arena occupancy flag for matchmaking pending logic.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.setBusy(busy)
	GameMatchState.arenaBusy = busy == true
end

function GameMatchState.isBusy()
	return GameMatchState.arenaBusy
end

return GameMatchState
