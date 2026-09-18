local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy()
	arenaBusy = true
end

function MatchStateService.setArenaIdle()
	if not arenaBusy then
		return
	end
	arenaBusy = false
	for _, callback in onIdleCallbacks do
		task.defer(callback)
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
