--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local busy = false
local freeCallbacks = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value == true
end

function MatchStateService.onArenaFree(callback)
	table.insert(freeCallbacks, callback)
end

function MatchStateService.signalArenaFree()
	for _, callback in freeCallbacks do
		task.spawn(callback)
	end
end

return MatchStateService
