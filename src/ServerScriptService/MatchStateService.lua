local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setMatchActive()
	arenaBusy = true
end

function MatchStateService.setMatchEnded()
	arenaBusy = false
end

return MatchStateService
