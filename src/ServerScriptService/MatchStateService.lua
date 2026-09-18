--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local busy = false

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy()
	busy = true
end

function MatchStateService.tryAcquire()
	if busy then
		return false
	end
	busy = true
	return true
end

function MatchStateService.clearBusy()
	busy = false
end

return MatchStateService
