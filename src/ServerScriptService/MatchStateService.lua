--[[
	MatchStateService — tracks whether the arena is busy with an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local freeListeners = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not arenaBusy then
		for _, listener in freeListeners do
			task.spawn(listener)
		end
	end
end

function MatchStateService.onArenaFree(listener)
	table.insert(freeListeners, listener)
end

return MatchStateService
