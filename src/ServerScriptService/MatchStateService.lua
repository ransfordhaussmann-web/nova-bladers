--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.markBusy()
	arenaBusy = true
end

function MatchStateService.markIdle()
	arenaBusy = false
end

return MatchStateService
