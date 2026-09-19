--[[
	MatchStateService — tracks whether the arena is free or a match is running.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy()
	arenaBusy = true
end

function MatchStateService.setArenaIdle()
	arenaBusy = false
	for _, callback in onIdleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
