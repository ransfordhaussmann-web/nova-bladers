local MatchStateService = {
	_busy = false,
}

function MatchStateService.setBusy(busy)
	MatchStateService._busy = busy == true
end

function MatchStateService.isBusy()
	return MatchStateService._busy
end

return MatchStateService
