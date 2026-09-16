--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local busy = false
local listeners = {}

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	if busy == value then
		return
	end
	busy = value
	for _, listener in listeners do
		listener(value)
	end
end

function MatchStateService.onBusyChanged(listener)
	table.insert(listeners, listener)
end

return MatchStateService
