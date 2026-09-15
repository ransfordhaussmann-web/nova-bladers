--[[
	MatchStateService — tracks whether the arena is busy so matchmaking can queue pending matches.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallbacks = {}

function MatchStateService.setBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy
	if wasBusy and not busy then
		for _, callback in onArenaFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	table.insert(onArenaFreeCallbacks, callback)
end

return MatchStateService
