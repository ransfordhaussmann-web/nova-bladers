--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onIdleCallback = nil

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy()
	arenaBusy = true
end

function MatchStateService.setIdle()
	arenaBusy = false
	if onIdleCallback then
		onIdleCallback()
	end
end

function MatchStateService.onArenaIdle(callback)
	onIdleCallback = callback
end

return MatchStateService
