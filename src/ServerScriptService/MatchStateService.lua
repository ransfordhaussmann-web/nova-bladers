--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {
	_busy = false,
}

function MatchStateService.isBusy()
	return MatchStateService._busy
end

function MatchStateService.setBusy(busy)
	MatchStateService._busy = busy
end

return MatchStateService
