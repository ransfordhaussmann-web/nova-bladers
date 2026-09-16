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
	if not busy then
		for _, callback in onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
