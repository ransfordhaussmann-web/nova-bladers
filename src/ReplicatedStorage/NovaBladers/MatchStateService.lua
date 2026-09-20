--[[
	MatchStateService — shared arena-busy flag for GameManager and MatchmakingService.
]]

local MatchStateService = {
	arenaBusy = false,
	activeModeId = nil,
}

function MatchStateService.setBusy(modeId)
	MatchStateService.arenaBusy = true
	MatchStateService.activeModeId = modeId
end

function MatchStateService.setIdle()
	MatchStateService.arenaBusy = false
	MatchStateService.activeModeId = nil
end

function MatchStateService.isBusy()
	return MatchStateService.arenaBusy
end

return MatchStateService
