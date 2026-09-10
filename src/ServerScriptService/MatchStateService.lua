local MatchStateService = {}

local busy = false
local listeners = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
	if not busy then
		for _, callback in listeners do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(listeners, callback)
end

return MatchStateService
