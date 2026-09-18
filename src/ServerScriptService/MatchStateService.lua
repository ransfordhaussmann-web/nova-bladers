--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
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
	if not busy then
		return
	end
	busy = false
	for _, callback in onIdleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
