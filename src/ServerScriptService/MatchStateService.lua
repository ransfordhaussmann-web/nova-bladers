--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.setIdle()
	arenaBusy = false
end

return MatchStateService
