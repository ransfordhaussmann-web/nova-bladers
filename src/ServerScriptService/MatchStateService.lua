local MatchStateService = {}

local arenaOccupied = false

function MatchStateService.isArenaOccupied()
	return arenaOccupied
end

function MatchStateService.setArenaOccupied(occupied)
	arenaOccupied = occupied == true
end

return MatchStateService
