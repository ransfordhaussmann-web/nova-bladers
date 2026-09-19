--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local busy = false
local freeListeners = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	if busy == value then
		return
	end
	busy = value
	if not busy then
		for _, listener in freeListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.onArenaFree(listener)
	table.insert(freeListeners, listener)
end

return MatchStateService
