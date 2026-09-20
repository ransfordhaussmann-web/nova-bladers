--[[
	MatchStateService — Arena belegt / frei (für Pending-Queue).
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.markBusy()
	arenaBusy = true
end

function MatchStateService.markIdle()
	arenaBusy = false
end

return MatchStateService
