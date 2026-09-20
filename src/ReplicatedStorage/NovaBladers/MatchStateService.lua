--[[
	MatchStateService — shared arena-busy flag between GameManager and MatchmakingService.
]]

local MatchStateService = {}

local arenaBusy = false
local onMatchEndedCallback = nil

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onMatchEnded(callback)
	onMatchEndedCallback = callback
end

function MatchStateService.signalMatchEnded()
	if onMatchEndedCallback then
		onMatchEndedCallback()
	end
end

return MatchStateService
