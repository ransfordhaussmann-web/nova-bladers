--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in onArenaFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(onArenaFreeCallbacks, callback)
end

return MatchStateService
