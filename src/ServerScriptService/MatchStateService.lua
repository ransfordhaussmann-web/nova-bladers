--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy
end

function MatchStateService.onMatchStarted()
	arenaBusy = true
end

function MatchStateService.onMatchEnded()
	arenaBusy = false
end

return MatchStateService
