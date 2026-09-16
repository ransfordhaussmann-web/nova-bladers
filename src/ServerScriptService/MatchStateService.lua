--[[
	MatchStateService — tracks whether the arena is currently in use.
]]

local MatchStateService = {}

local arenaBusy = false

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy()
	arenaBusy = true
end

function MatchStateService.setArenaIdle()
	arenaBusy = false
end

return MatchStateService
