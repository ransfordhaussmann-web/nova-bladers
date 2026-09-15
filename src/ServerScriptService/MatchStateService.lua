local MatchStateService = {}

local isBusy = false
local onFreedCallbacks = {}

function MatchStateService.setBusy(busy)
	if isBusy == busy then
		return
	end
	isBusy = busy
	if not busy then
		for _, callback in onFreedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return isBusy
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
