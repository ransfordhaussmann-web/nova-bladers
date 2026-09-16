--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local busy = false
local onFreeCallbacks = {}

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
	for _, callback in onFreeCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaFree(callback)
	table.insert(onFreeCallbacks, callback)
end

return MatchStateService
