--[[
	Tracks whether the arena is free for a new match.
]]

local MatchStateService = {}

local arenaState = "idle"
local idleCallbacks = {}

function MatchStateService.isIdle()
	return arenaState == "idle"
end

function MatchStateService.setOccupied()
	arenaState = "occupied"
end

function MatchStateService.setIdle()
	if arenaState == "idle" then
		return
	end
	arenaState = "idle"
	for _, callback in idleCallbacks do
		task.spawn(callback)
	end
end

function MatchStateService.onIdle(callback)
	table.insert(idleCallbacks, callback)
end

return MatchStateService
