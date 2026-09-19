--[[
	MatchStateService — Arena-Belegung (Match läuft / frei).
]]

local MatchStateService = {
	_busy = false,
}

function MatchStateService.isArenaBusy()
	return MatchStateService._busy
end

function MatchStateService.setBusy()
	MatchStateService._busy = true
end

function MatchStateService.setIdle()
	MatchStateService._busy = false
end

return MatchStateService
