--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaOccupied = false
local onEndedCallbacks = {}

function MatchStateService.isArenaOccupied()
	return arenaOccupied
end

function MatchStateService.setArenaOccupied(occupied)
	arenaOccupied = occupied
end

function MatchStateService.onMatchEnded(callback)
	table.insert(onEndedCallbacks, callback)
end

function MatchStateService.notifyMatchEnded()
	for _, callback in onEndedCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
