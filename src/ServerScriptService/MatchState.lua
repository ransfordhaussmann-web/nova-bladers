--[[
	MatchState — tracks whether the arena is currently running a match.
]]

local MatchState = {
	busy = false,
}

function MatchState.isBusy()
	return MatchState.busy
end

function MatchState.setBusy()
	MatchState.busy = true
end

function MatchState.setIdle()
	MatchState.busy = false
end

return MatchState
