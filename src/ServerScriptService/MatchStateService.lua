local MatchStateService = {
	_arenaBusy = false,
	_onFreed = nil,
}

function MatchStateService.setArenaBusy(busy)
	MatchStateService._arenaBusy = busy
end

function MatchStateService.isArenaBusy()
	return MatchStateService._arenaBusy
end

function MatchStateService.onArenaFreed(callback)
	MatchStateService._onFreed = callback
end

function MatchStateService.notifyArenaFreed()
	if MatchStateService._onFreed then
		MatchStateService._onFreed()
	end
end

return MatchStateService
