--[[
	MatchStateService — shared arena-busy flag for matchmaking pending state.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

return MatchStateService
