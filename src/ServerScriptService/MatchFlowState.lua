--[[
	MatchFlowState — tracks whether the arena is occupied by an active match.
]]

local MatchFlowState = {
	busy = false,
}

function MatchFlowState.setBusy(value)
	MatchFlowState.busy = value == true
end

function MatchFlowState.isBusy()
	return MatchFlowState.busy
end

return MatchFlowState
