--[[
	Tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local busy = false
local onIdleCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy()
	busy = true
end

function MatchStateService.setIdle()
	busy = false
	for _, callback in onIdleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
