--[[
	MatchStateService — trackt ob die Arena gerade in einem Match ist.
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
