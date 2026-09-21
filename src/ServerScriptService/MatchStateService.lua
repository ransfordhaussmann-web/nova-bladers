--[[
	MatchStateService — Arena-Belegung (Match läuft / frei).
]]

local MatchStateService = {}

local arenaBusy = false
local listeners = {}

local function notify()
	for _, callback in listeners do
		task.spawn(callback, arenaBusy)
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	notify()
end

function MatchStateService.onArenaStateChanged(callback)
	table.insert(listeners, callback)
end

return MatchStateService
