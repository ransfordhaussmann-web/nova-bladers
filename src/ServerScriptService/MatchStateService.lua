local MatchStateService = {
	busy = false,
}

function MatchStateService.isBusy()
	return MatchStateService.busy
end

function MatchStateService.setBusy(value)
	MatchStateService.busy = value
end

return MatchStateService
