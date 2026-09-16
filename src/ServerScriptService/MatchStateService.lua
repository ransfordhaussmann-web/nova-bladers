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
	for _, listener in listeners do
		task.spawn(listener, busy)
	end
end

function MatchStateService.onStateChanged(listener)
	table.insert(listeners, listener)
end

return MatchStateService
