--[[
	MatchStateService — tracks whether the arena is occupied by an active match.
]]

local MatchStateService = {}

local arenaBusy = false
local onFreedCallback = nil

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.setArenaBusy(busy)
	if arenaBusy == busy then
		return
	end
	arenaBusy = busy
	if not busy and onFreedCallback then
		onFreedCallback()
	end
end

function MatchStateService.onArenaFreed(callback)
	onFreedCallback = callback
end

return MatchStateService
