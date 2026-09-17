local MatchStateService = {}

local matchActive = false
local onArenaFreeCallbacks = {}

function MatchStateService.isMatchActive()
	return matchActive
end

function MatchStateService.isArenaAvailable()
	return not matchActive
end

function MatchStateService.setMatchActive(active)
	matchActive = active == true
	if not matchActive then
		for _, callback in onArenaFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(onArenaFreeCallbacks, callback)
end

return MatchStateService
