--[[
	MatchStateService — tracks whether the arena is busy with an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.onArenaFree(callback)
	table.insert(onArenaFreeCallbacks, callback)
end

function MatchStateService.notifyArenaFree()
	for _, callback in onArenaFreeCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
