local GameMatchState = {}

local arenaBusy = false

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy == true
end

function GameMatchState.isArenaBusy()
	return arenaBusy
end

return GameMatchState
