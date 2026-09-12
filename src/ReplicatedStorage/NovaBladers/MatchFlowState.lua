local MatchFlowState = {}

local arenaBusy = false

function MatchFlowState.isArenaBusy()
	return arenaBusy
end

function MatchFlowState.setArenaBusy(busy)
	arenaBusy = busy == true
end

return MatchFlowState
