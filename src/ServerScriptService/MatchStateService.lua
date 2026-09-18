local MatchStateService = {}

local arenaBusy = false
local onFreeCallback = nil

function MatchStateService.setBusy(busy)
	arenaBusy = busy
end

function MatchStateService.isBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	onFreeCallback = callback
end

function MatchStateService.notifyArenaFree()
	if onFreeCallback then
		onFreeCallback()
	end
end

return MatchStateService
