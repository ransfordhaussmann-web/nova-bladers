local GameMatchState = {}

local arenaBusy = false
local freeCallbacks = {}

function GameMatchState.isArenaBusy()
	return arenaBusy
end

function GameMatchState.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in freeCallbacks do
			task.spawn(callback)
		end
	end
end

function GameMatchState.onArenaFree(callback)
	table.insert(freeCallbacks, callback)
end

return GameMatchState
