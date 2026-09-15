--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local freeCallbacks = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in freeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(freeCallbacks, callback)
end

return MatchStateService
