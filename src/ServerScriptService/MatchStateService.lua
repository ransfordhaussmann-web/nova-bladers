local MatchStateService = {}

local busy = false
local freeCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	if busy == value then
		return
	end
	busy = value
	if not busy then
		for _, callback in freeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(freeCallbacks, callback)
end

return MatchStateService
