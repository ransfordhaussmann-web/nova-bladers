local GameMatchState = {}

local arenaBusy = false
local freeCallbacks = {}

function GameMatchState.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy then
		for _, callback in freeCallbacks do
			task.spawn(callback)
		end
	end
end

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.onArenaFree(callback)
	table.insert(freeCallbacks, callback)
end

return GameMatchState
