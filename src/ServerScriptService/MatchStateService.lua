--[[
	MatchStateService — tracks whether the arena is busy with an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in onFreedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
