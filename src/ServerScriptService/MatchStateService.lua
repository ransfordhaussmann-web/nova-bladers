local MatchStateService = {}

local inMatch = false
local idleCallbacks = {}

function MatchStateService.isInMatch()
	return inMatch
end

function MatchStateService.setInMatch(value)
	inMatch = value == true
	if not inMatch then
		for _, callback in idleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
