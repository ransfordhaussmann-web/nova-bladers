--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreedCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in onArenaFreedCallbacks do
			task.defer(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onArenaFreedCallbacks, callback)
end

return MatchStateService
