--[[
	MatchStateService — tracks whether the arena is busy with an active match.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

return MatchStateService
