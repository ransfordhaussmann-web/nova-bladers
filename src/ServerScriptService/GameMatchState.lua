local GameMatchState = {}

local arenaBusy = false

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy
end

function GameMatchState.isArenaBusy()
	return arenaBusy
end

return GameMatchState
