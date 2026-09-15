--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local listeners = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	for _, callback in listeners do
		task.spawn(callback, busy)
	end
end

function MatchStateService.onBusyChanged(callback)
	table.insert(listeners, callback)
end

return MatchStateService
