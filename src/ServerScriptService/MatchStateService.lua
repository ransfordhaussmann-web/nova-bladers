local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.clearBusy()
	arenaBusy = false
end

return MatchStateService
