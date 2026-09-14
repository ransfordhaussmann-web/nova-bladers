--[[
	Shared match-active flag so matchmaking can defer starts while a fight runs.
]]

local MatchStateService = {}

local matchActive = false
local onIdleCallbacks = {}

function MatchStateService.isMatchActive()
	return matchActive
end

function MatchStateService.setMatchActive(active)
	matchActive = active == true
	if not matchActive then
		for _, callback in onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onMatchIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
