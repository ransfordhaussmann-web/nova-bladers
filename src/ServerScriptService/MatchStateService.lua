--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.setBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in onIdleCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
