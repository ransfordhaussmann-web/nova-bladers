local MatchStateService = {}

local busy = false

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy()
	busy = true
end

function MatchStateService.setIdle()
	busy = false
end

return MatchStateService
