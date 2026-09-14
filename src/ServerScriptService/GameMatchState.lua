local GameMatchState = {
	arenaBusy = false,
	activeModeId = nil,
}

function GameMatchState.setArenaBusy(busy, modeId)
	GameMatchState.arenaBusy = busy
	GameMatchState.activeModeId = busy and modeId or nil
end

function GameMatchState.isArenaFree()
	return not GameMatchState.arenaBusy
end

function GameMatchState.getActiveModeId()
	return GameMatchState.activeModeId
end

return GameMatchState
