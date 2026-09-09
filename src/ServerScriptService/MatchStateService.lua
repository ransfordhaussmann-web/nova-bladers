--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
