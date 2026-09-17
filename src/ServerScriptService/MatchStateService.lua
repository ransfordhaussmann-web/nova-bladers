local MatchStateService = {}

local busy = false
local listeners = {}

function MatchStateService.setBusy(isBusy)
	if busy == isBusy then
		return
	end
	busy = isBusy
	for _, callback in listeners do
		task.spawn(callback, busy)
	end
end

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.onBusyChanged(callback)
	table.insert(listeners, callback)
end

return MatchStateService
