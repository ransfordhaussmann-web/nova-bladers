--[[
	MatchStateService — shared arena occupancy flag for matchmaking + GameManager.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.setBusy(busy)
	arenaBusy = busy == true
end

return MatchStateService
