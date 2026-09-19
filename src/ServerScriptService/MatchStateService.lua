--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local matchActive = false
local onMatchEnd = nil

function MatchStateService.setActive(active)
	matchActive = active
end

function MatchStateService.isActive()
	return matchActive
end

function MatchStateService.setOnMatchEnd(callback)
	onMatchEnd = callback
end

function MatchStateService.notifyMatchEnded()
	if onMatchEnd then
		onMatchEnd()
	end
end

return MatchStateService
