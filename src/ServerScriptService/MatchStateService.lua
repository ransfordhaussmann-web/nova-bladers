--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
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

function MatchStateService.onArenaBusyChanged(callback)
	table.insert(listeners, callback)
end

return MatchStateService
