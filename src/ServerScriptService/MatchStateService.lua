local MatchStateService = {}

local busy = false

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
end

return MatchStateService
