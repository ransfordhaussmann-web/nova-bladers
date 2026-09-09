--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallbacks = {}

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in onFreedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
