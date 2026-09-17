local MatchStateService = {}

local busy = false
local onFreedCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
	if not busy then
		for _, callback in onFreedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
