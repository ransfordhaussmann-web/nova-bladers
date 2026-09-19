local MatchStateService = {}

local arenaBusy = false
local freedListeners = {}

function MatchStateService.setArenaBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy == true
	if wasBusy and not arenaBusy then
		for _, listener in freedListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFreed(listener)
	table.insert(freedListeners, listener)
end

return MatchStateService
