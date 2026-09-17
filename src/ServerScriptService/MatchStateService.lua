--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false
local pendingMatches = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in pendingMatches do
			task.spawn(callback)
		end
		pendingMatches = {}
	end
end

function MatchStateService.whenArenaFree(callback)
	if not arenaBusy then
		callback()
		return
	end
	table.insert(pendingMatches, callback)
end

return MatchStateService
