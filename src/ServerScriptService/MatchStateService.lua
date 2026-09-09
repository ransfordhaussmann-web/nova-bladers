--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local busy = false
local onIdleCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

function MatchStateService.notifyArenaIdle()
	for _, callback in onIdleCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
