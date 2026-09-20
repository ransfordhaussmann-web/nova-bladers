--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onEndedCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
end

function MatchStateService.onMatchEnded(callback)
	table.insert(onEndedCallbacks, callback)
end

function MatchStateService.notifyMatchEnded()
	arenaBusy = false
	for _, callback in onEndedCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
