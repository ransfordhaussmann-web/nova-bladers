--[[
	MatchStateService — tracks whether the arena is available for a new match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreeCallbacks = {}

function MatchStateService.isAvailable()
	return not arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, callback in onFreeCallbacks do
			task.spawn(callback)
		end
		onFreeCallbacks = {}
	end
end

function MatchStateService.whenAvailable(callback)
	if not arenaBusy then
		callback()
	else
		table.insert(onFreeCallbacks, callback)
	end
end

return MatchStateService
