--[[
	MatchStateService — shared match-busy flag for GameManager and MatchmakingService.
]]

local MatchStateService = {}

local isBusyFn = function()
	return false
end

local onMatchEndedFn

function MatchStateService.register(handlers)
	if handlers.isBusy then
		isBusyFn = handlers.isBusy
	end
	if handlers.onMatchEnded then
		onMatchEndedFn = handlers.onMatchEnded
	end
end

function MatchStateService.isBusy()
	return isBusyFn()
end

function MatchStateService.notifyMatchEnded()
	if onMatchEndedFn then
		onMatchEndedFn()
	end
end

return MatchStateService
