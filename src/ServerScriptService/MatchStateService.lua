local MatchStateService = {}

local matchActive = false

function MatchStateService.setActive(active)
	matchActive = active == true
end

function MatchStateService.isActive()
	return matchActive
end

return MatchStateService
