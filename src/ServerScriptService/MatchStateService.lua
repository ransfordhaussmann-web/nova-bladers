--[[
	MatchStateService — tracks whether the arena is free for a new match.
]]

local MatchStateService = {}

local arenaIdle = true
local onIdleCallbacks = {}

function MatchStateService.isIdle()
	return arenaIdle
end

function MatchStateService.setBusy()
	arenaIdle = false
end

function MatchStateService.setIdle()
	if arenaIdle then
		return
	end
	arenaIdle = true
	for _, callback in onIdleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onArenaIdle(callback)
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
