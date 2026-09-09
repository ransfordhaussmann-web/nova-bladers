--[[
	MatchStateService — shared arena-busy flag between GameManager and MatchmakingService.
]]

local MatchStateService = {}

local arenaBusy = false
local listeners = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	for _, callback in listeners do
		callback(busy)
	end
end

function MatchStateService.onArenaBusyChanged(callback)
	table.insert(listeners, callback)
end

return MatchStateService
