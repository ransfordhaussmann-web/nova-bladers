--[[
	MatchStateService — Arena belegt / frei für Matchmaking.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.onMatchStarted()
	arenaBusy = true
end

function MatchStateService.onMatchEnded()
	arenaBusy = false
	for _, callback in onFreedCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
