--[[
	MatchStateService — tracks whether the arena is busy so queues can wait.
]]

local MatchStateService = {}

local isBusy = false
local freeListeners = {}

function MatchStateService.setBusy(busy)
	if isBusy == busy then
		return
	end
	isBusy = busy
	if not busy then
		for _, listener in freeListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.isBusy()
	return isBusy
end

function MatchStateService.onArenaFree(listener)
	table.insert(freeListeners, listener)
end

return MatchStateService
