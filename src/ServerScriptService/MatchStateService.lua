--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local freeCallbacks = {}

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	local wasBusy = arenaBusy
	arenaBusy = busy
	if wasBusy and not busy then
		for _, callback in freeCallbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.onArenaFreed(callback)
	table.insert(freeCallbacks, callback)
end

return MatchStateService
