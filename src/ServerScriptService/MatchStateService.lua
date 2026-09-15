--[[
	MatchStateService — tracks whether the arena is free for a new match.
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
