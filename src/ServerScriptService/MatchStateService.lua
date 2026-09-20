--[[
	MatchStateService — tracks whether the arena is currently in use.
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
