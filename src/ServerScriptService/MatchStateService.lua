local MatchStateService = {}

local arenaBusy = false
local idleListeners = {}

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy then
		for _, listener in idleListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaIdle(listener)
	table.insert(idleListeners, listener)
end

return MatchStateService
