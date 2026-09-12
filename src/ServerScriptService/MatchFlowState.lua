--[[
	MatchFlowState — tracks whether the arena is occupied so queues can show a pending status.
]]

local MatchFlowState = {
	arenaBusy = false,
}

function MatchFlowState.setArenaBusy(busy)
	MatchFlowState.arenaBusy = busy
end

function MatchFlowState.isArenaBusy()
	return MatchFlowState.arenaBusy
end

return MatchFlowState
