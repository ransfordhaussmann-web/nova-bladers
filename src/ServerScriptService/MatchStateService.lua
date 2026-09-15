--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local isBusy = false
local onFreeCallbacks = {}

function MatchStateService.setBusy(busy)
	if isBusy == busy then
		return
	end
	isBusy = busy
	if not busy then
		for _, callback in onFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return isBusy
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

return MatchStateService
