--[[
	MatchStateService — tracks whether the arena is busy with an active match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.isArenaFree()
	return not arenaBusy
end

return MatchStateService
