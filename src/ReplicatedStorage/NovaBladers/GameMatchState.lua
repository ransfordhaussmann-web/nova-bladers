local GameMatchState = {
	arenaBusy = false,
	activeMode = nil,
}

function GameMatchState.setBusy(busy, mode)
	GameMatchState.arenaBusy = busy == true
	GameMatchState.activeMode = busy and mode or nil
end

function GameMatchState.isBusy()
	return GameMatchState.arenaBusy
end

function GameMatchState.getActiveMode()
	return GameMatchState.activeMode
end

return GameMatchState
