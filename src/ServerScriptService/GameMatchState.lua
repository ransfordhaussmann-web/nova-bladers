--[[
	GameMatchState — tracks whether the arena is running a match.
	Matchmaking waits when busy; GameManager marks free after cleanup.
]]

local GameMatchState = {}

local arenaBusy = false

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy == true
end

return GameMatchState
