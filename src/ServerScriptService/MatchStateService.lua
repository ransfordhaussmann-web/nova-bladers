--[[
	MatchStateService — tracks whether the arena is free for a new match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallbacks = {}

function MatchStateService.isAvailable()
	return not arenaBusy
end

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.setIdle()
	if not arenaBusy then
		return
	end
	arenaBusy = false
	for _, callback in onFreedCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
