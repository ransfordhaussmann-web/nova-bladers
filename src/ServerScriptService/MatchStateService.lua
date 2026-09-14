--[[
	MatchStateService — tracks whether the arena is running a match.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallback

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy()
	arenaBusy = true
end

function MatchStateService.setArenaIdle()
	if not arenaBusy then
		return
	end
	arenaBusy = false
	if onIdleCallback then
		onIdleCallback()
	end
end

function MatchStateService.onArenaIdle(callback)
	onIdleCallback = callback
end

return MatchStateService
