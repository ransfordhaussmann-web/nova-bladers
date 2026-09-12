--[[
	MatchState — shared arena-busy flag for matchmaking pending logic.
]]

local MatchState = {
	busy = false,
}

function MatchState.setBusy(value)
	MatchState.busy = value == true
end

function MatchState.isBusy()
	return MatchState.busy
end

return MatchState
