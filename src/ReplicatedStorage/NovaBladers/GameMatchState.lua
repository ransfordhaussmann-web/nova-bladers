--[[
	GameMatchState — tracks whether the arena is currently in use.
]]

local GameMatchState = {}

local arenaBusy = false

function GameMatchState.setBusy(busy)
	arenaBusy = busy == true
end

function GameMatchState.isBusy()
	return arenaBusy
end

return GameMatchState
