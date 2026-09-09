--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

return MatchStateService
