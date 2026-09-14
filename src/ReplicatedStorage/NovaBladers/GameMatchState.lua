local GameMatchState = {}

local arenaBusy = false
local onFreeCallbacks = {}

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy == true
end

function GameMatchState.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

function GameMatchState.notifyArenaFree()
	for _, callback in onFreeCallbacks do
		task.spawn(callback)
	end
end

return GameMatchState
