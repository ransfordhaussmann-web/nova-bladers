--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy then
		for _, callback in onFreedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
