--[[
	MatchStateService — tracks whether the arena is busy with an active match.
]]

local MatchStateService = {}

local busy = false
local freedCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	if busy == value then
		return
	end
	busy = value
	if not busy then
		for _, callback in freedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(freedCallbacks, callback)
end

return MatchStateService
