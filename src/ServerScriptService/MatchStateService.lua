--[[
	MatchStateService — shared arena occupancy for matchmaking.
]]

local MatchStateService = {}

local isArenaFreeFn = function()
	return true
end

function MatchStateService.registerArenaState(fn)
	isArenaFreeFn = fn
end

function MatchStateService.isArenaFree()
	return isArenaFreeFn()
end

return MatchStateService
