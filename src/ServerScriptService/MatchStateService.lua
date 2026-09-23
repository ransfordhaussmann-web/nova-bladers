local MatchStateService = {}

local idle = true

function MatchStateService.setIdle(value)
	idle = value == true
end

function MatchStateService.isIdle()
	return idle
end

return MatchStateService
