--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local matchActive = false
local onMatchEndCallback = nil

function MatchStateService.setMatchActive(active)
	matchActive = active == true
end

function MatchStateService.isArenaBusy()
	return matchActive
end

function MatchStateService.onMatchEnd(callback)
	onMatchEndCallback = callback
end

function MatchStateService.notifyMatchEnd()
	if onMatchEndCallback then
		onMatchEndCallback()
	end
end

return MatchStateService
