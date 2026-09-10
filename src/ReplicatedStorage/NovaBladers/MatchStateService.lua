--[[
	MatchStateService — shared arena-busy flag for matchmaking pending state.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setBusy(busy)
	arenaBusy = busy == true
end

function MatchStateService.isBusy()
	return arenaBusy
end

return MatchStateService
