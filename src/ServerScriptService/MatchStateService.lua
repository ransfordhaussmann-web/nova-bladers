local MatchStateService = {
	_busy = false,
	_activeMode = nil,
}

function MatchStateService.isBusy()
	return MatchStateService._busy
end

function MatchStateService.getActiveMode()
	return MatchStateService._activeMode
end

function MatchStateService.setBusy(busy, modeId)
	MatchStateService._busy = busy
	MatchStateService._activeMode = busy and modeId or nil
end

return MatchStateService
