--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local busy = false
local onEndedCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
end

function MatchStateService.onMatchEnded(callback)
	table.insert(onEndedCallbacks, callback)
end

function MatchStateService.notifyMatchEnded()
	for _, callback in onEndedCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
