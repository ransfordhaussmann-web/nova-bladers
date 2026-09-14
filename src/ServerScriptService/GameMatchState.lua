local GameMatchState = {
	_busy = false,
	_freeCallbacks = {},
}

function GameMatchState.isBusy()
	return GameMatchState._busy
end

function GameMatchState.setBusy(busy)
	if GameMatchState._busy == busy then
		return
	end
	GameMatchState._busy = busy
	if not busy then
		for _, callback in GameMatchState._freeCallbacks do
			task.spawn(callback)
		end
	end
end

function GameMatchState.onArenaFree(callback)
	table.insert(GameMatchState._freeCallbacks, callback)
end

return GameMatchState
