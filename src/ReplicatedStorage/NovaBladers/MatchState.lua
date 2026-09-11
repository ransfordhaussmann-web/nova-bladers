local MatchState = {}

local arenaBusy = false

function MatchState.isArenaBusy()
	return arenaBusy
end

function MatchState.setArenaBusy(busy)
	arenaBusy = busy == true
end

return MatchState
