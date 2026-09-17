--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy == true
end

return MatchStateService
