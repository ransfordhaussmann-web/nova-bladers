--[[
	MatchStateService — shared arena-busy flag for GameManager and MatchmakingService.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
end

return MatchStateService
