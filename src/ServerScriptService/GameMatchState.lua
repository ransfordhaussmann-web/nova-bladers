local GameMatchState = {
	arenaOccupied = false,
}

function GameMatchState.setArenaOccupied(occupied)
	GameMatchState.arenaOccupied = occupied == true
end

function GameMatchState.isArenaOccupied()
	return GameMatchState.arenaOccupied
end

return GameMatchState
