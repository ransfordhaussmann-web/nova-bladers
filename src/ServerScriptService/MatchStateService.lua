--[[
	MatchStateService — tracks whether the arena is free for a new match.
]]

local MatchStateService = {}

local arenaBusy = false
local onAvailableCallbacks = {}

function MatchStateService.isArenaAvailable()
	return not arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not arenaBusy then
		for _, callback in onAvailableCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaAvailable(callback)
	table.insert(onAvailableCallbacks, callback)
end

return MatchStateService
