--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreeCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy then
		for _, callback in onFreeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

return MatchStateService
