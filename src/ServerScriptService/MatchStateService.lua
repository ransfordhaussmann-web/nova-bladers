--[[
	Tracks whether the arena is busy so queues can wait for the current match.
]]

local MatchStateService = {}

local busy = false
local idleCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy()
	busy = true
end

function MatchStateService.setIdle()
	if not busy then
		return
	end
	busy = false
	for _, callback in idleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
