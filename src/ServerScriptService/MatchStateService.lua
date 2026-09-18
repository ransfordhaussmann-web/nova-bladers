--[[
	MatchStateService — tracks whether the arena is busy so queues can wait.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy

	if wasBusy and not busy then
		for _, callback in onArenaFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(onArenaFreeCallbacks, callback)
end

return MatchStateService
