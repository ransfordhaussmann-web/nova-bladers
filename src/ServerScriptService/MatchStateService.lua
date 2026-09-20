local MatchStateService = {
	_busy = false,
}

function MatchStateService.setBusy(value)
	MatchStateService._busy = value == true
end

function MatchStateService.isBusy()
	return MatchStateService._busy
end

return MatchStateService
