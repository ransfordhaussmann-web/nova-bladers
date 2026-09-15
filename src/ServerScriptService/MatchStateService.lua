local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.setIdle()
	arenaBusy = false
	for _, callback in onIdleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
