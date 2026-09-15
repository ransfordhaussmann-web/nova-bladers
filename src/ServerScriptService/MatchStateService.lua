--[[
	MatchStateService — Arena belegt/frei für Queue-Pending-Status.
]]

local MatchStateService = {}

local arenaBusy = false
local freeListeners = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, listener in freeListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(freeListeners, callback)
end

return MatchStateService
