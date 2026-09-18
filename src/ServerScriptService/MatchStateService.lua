--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local freedCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in freedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.tryReserve()
	if arenaBusy then
		return false
	end
	arenaBusy = true
	return true
end

function MatchStateService.onArenaFreed(callback)
	table.insert(freedCallbacks, callback)
end

return MatchStateService
