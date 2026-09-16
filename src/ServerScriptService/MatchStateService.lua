--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local busy = false

function MatchStateService.setBusy(value)
	busy = value == true
end

function MatchStateService.isBusy()
	return busy
end

return MatchStateService
