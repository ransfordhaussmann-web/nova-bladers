--[[
	MatchStateService — shared arena-busy flag for queue + GameManager.
]]

local MatchStateService = {}

local busy = false
local onFreeCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
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
