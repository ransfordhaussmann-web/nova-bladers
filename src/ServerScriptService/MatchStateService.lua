--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local freedCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	if arenaBusy == busy then
		return
	end

	arenaBusy = busy
	if not busy then
		local callbacks = freedCallbacks
		freedCallbacks = {}
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	if not arenaBusy then
		task.spawn(callback)
		return
	end
	table.insert(freedCallbacks, callback)
end

return MatchStateService
