--[[
	GameMatchState — shared arena occupancy flag for matchmaking.
]]

local GameMatchState = {
	arenaBusy = false,
}

function GameMatchState.setBusy(busy)
	GameMatchState.arenaBusy = busy
end

function GameMatchState.isBusy()
	return GameMatchState.arenaBusy
end

return GameMatchState
