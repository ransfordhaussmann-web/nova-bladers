--[[
	GameMatchState — tracks whether the arena is occupied by an active match.
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
