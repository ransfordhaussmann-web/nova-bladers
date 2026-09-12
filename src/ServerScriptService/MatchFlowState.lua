local MatchFlowState = {}

local arenaBusy = false

function MatchFlowState.setArenaBusy(busy)
	arenaBusy = busy == true
end

function MatchFlowState.isArenaBusy()
	return arenaBusy
end

return MatchFlowState
