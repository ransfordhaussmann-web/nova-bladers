local MatchStateService = {
	_busy = false,
}

function MatchStateService.isBusy()
	return MatchStateService._busy
end

function MatchStateService.setBusy(busy)
	MatchStateService._busy = busy == true
end

return MatchStateService
