--[[
	MatchState — tracks whether the arena is currently running a match.
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
