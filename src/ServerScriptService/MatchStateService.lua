--[[
	MatchStateService — shared arena-busy flag for Matchmaking + GameManager.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy then
		local callbacks = onArenaFreeCallbacks
		onArenaFreeCallbacks = {}
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	if not arenaBusy then
		task.spawn(callback)
	else
		table.insert(onArenaFreeCallbacks, callback)
	end
end

return MatchStateService
