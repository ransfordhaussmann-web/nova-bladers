--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreeCallbacks = {}

function MatchStateService.setArenaBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy
	if wasBusy and not busy then
		for _, callback in onFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

return MatchStateService
