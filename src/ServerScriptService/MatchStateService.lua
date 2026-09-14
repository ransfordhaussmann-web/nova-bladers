--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local listeners = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	for _, listener in listeners do
		task.spawn(listener, busy)
	end
end

function MatchStateService.onArenaBusyChanged(listener)
	table.insert(listeners, listener)
end

return MatchStateService
