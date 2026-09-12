--[[
	Shared arena-busy flag for MatchmakingService and GameManager.
]]

local MatchFlowState = {
	arenaBusy = false,
}

function MatchFlowState.setArenaBusy(busy)
	MatchFlowState.arenaBusy = busy == true
end

function MatchFlowState.isArenaBusy()
	return MatchFlowState.arenaBusy
end

return MatchFlowState
