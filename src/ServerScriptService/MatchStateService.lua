local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setBusy(value)
	arenaBusy = value == true
end

function MatchStateService.isBusy()
	return arenaBusy
end

return MatchStateService
