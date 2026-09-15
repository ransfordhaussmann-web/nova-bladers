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
	busy = value == true
	if not busy then
		for _, callback in listeners do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onFreed(callback)
	table.insert(listeners, callback)
end

return MatchStateService
