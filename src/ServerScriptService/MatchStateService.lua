--[[
	MatchStateService — tracks whether the arena is running a match.
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
		for _, callback in freedCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(freedCallbacks, callback)
end

return MatchStateService
