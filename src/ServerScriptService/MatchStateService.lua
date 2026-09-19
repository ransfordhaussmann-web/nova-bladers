--[[
	MatchStateService — shared arena-busy flag for matchmaking vs. GameManager.
]]

local MatchStateService = {}

local isBusy = false

function MatchStateService.setBusy(busy)
	isBusy = busy == true
end

function MatchStateService.isBusy()
	return isBusy
end

return MatchStateService
