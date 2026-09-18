local MatchStateService = {}

local arenaBusy = false
local idleCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in idleCallbacks do
			task.defer(callback)
		end
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
