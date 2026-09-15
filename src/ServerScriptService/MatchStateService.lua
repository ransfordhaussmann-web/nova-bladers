--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local busy = false
local idleCallbacks = {}

function MatchStateService.setBusy(value)
	busy = value == true
	if not busy then
		for _, callback in idleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.onArenaIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
