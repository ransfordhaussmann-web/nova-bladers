--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local listeners = {}

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
	for _, callback in listeners do
		callback(busy)
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(listeners, callback)
end

return MatchStateService
