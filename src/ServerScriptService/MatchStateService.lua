--[[
	MatchStateService — tracks whether the arena is currently running a match.
]]

local MatchStateService = {}

local busy = false

function MatchStateService.isBusy()
	return busy
end

function MatchStateService.setBusy(value)
	busy = value
end

return MatchStateService
