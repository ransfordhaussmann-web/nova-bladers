local GameMatchState = {
	inMatch = false,
}

function GameMatchState.setInMatch(active)
	GameMatchState.inMatch = active == true
end

function GameMatchState.isArenaBusy()
	return GameMatchState.inMatch
end

return GameMatchState
