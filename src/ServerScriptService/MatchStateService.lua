local MatchStateService = {}

local arenaBusy = false
local onFreeCallbacks = {}

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

function MatchStateService.notifyArenaFree()
	for _, callback in onFreeCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
