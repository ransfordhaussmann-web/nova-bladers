local MatchStateService = {
	busy = false,
}

function MatchStateService.setBusy(busy)
	MatchStateService.busy = busy == true
end

function MatchStateService.isBusy()
	return MatchStateService.busy
end

return MatchStateService
