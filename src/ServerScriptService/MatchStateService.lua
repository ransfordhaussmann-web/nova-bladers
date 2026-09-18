local MatchStateService = {}

local arenaBusy = false
local freedListeners = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, listener in freedListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.onArenaFreed(listener)
	table.insert(freedListeners, listener)
end

return MatchStateService
