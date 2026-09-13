--[[
	GameMatchState — tracks whether the arena is currently hosting a match.
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
