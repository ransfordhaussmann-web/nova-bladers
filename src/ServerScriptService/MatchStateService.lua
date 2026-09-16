--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
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
