--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallbacks = {}

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.setIdle()
	arenaBusy = false
	local callbacks = onIdleCallbacks
	onIdleCallbacks = {}
	for _, callback in callbacks do
		task.spawn(callback)
	end
end

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.whenIdle(callback)
	if not arenaBusy then
		task.spawn(callback)
		return
	end
	table.insert(onIdleCallbacks, callback)
end

return MatchStateService
