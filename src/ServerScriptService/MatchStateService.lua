--[[
	MatchStateService — Verfolgt, ob die Arena gerade belegt ist.
]]

local MatchStateService = {}

local busy = false
local onFreedCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy()
	busy = true
end

function MatchStateService.setFree()
	if not busy then
		return
	end
	busy = false
	for _, callback in onFreedCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(onFreedCallbacks, callback)
end

return MatchStateService
