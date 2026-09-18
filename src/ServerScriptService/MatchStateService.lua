--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {
	_busy = false,
	_onFreed = nil,
}

function MatchStateService.setBusy(busy)
	if MatchStateService._busy == busy then
		return
	end
	MatchStateService._busy = busy
	if not busy and MatchStateService._onFreed then
		MatchStateService._onFreed()
	end
end

function MatchStateService.isBusy()
	return MatchStateService._busy
end

function MatchStateService.onArenaFreed(callback)
	MatchStateService._onFreed = callback
end

return MatchStateService
