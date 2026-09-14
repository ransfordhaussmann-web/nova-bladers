--[[
	GameMatchState — shared arena-busy flag for matchmaking pending status.
]]

local GameMatchState = {
	_busy = false,
}

function GameMatchState.setBusy(busy)
	GameMatchState._busy = busy == true
end

function GameMatchState.isBusy()
	return GameMatchState._busy
end

return GameMatchState
