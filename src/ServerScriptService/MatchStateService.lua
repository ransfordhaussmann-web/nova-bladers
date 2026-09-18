--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setMatchActive(active)
	arenaBusy = active == true
	if not arenaBusy then
		for _, callback in onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
