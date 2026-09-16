local MatchStateService = {}

local busy = false
local idleCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
	if not busy then
		for _, callback in idleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
