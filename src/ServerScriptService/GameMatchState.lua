local GameMatchState = {}

local arenaBusy = false

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy
end

return GameMatchState
