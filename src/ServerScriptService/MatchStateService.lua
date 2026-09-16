--[[
	MatchStateService — trackt ob die Arena gerade belegt ist.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreeCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy == true
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

function MatchStateService.notifyArenaFree()
	for _, callback in onFreeCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
