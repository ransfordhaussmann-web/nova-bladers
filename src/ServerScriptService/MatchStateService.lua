local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(value)
	arenaBusy = value == true
end

return MatchStateService
