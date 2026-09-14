--[[
	MatchStateService — shared arena-busy flag for GameManager + MatchmakingService.
]]

local MatchStateService = {
	busy = false,
}

function MatchStateService.setBusy(value)
	MatchStateService.busy = value == true
end

function MatchStateService.isBusy()
	return MatchStateService.busy
end

function MatchStateService.markFreed()
	if MatchStateService.onFreed then
		MatchStateService.onFreed()
	end
end

return MatchStateService
