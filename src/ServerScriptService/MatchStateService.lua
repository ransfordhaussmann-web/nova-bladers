--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local isBusy = false
local listeners = {}

function MatchStateService.setBusy(busy)
	if isBusy == busy then
		return
	end
	isBusy = busy
	for _, callback in listeners do
		task.spawn(callback, busy)
	end
end

function MatchStateService.isBusy()
	return isBusy
end

function MatchStateService.onBusyChanged(callback)
	table.insert(listeners, callback)
end

return MatchStateService
