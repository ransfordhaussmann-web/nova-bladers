local MatchStateService = {}

local matchActive = false
local endedCallbacks = {}

function MatchStateService.isBusy()
	return matchActive
end

function MatchStateService.setActive(active)
	matchActive = active == true
end

function MatchStateService.onMatchEnded(callback)
	table.insert(endedCallbacks, callback)
end

function MatchStateService.notifyMatchEnded()
	for _, callback in endedCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
