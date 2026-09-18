--[[
	MatchStateService — tracks whether the arena is in use.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreeCallbacks = {}

function MatchStateService.setBusy(busy)
	arenaBusy = busy
	if not busy then
		local callbacks = onFreeCallbacks
		onFreeCallbacks = {}
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end
end

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.whenFree(callback)
	if not arenaBusy then
		task.spawn(callback)
	else
		table.insert(onFreeCallbacks, callback)
	end
end

return MatchStateService
