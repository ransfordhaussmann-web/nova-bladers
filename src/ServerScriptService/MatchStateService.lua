--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in onArenaFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	table.insert(onArenaFreeCallbacks, callback)
end

return MatchStateService
