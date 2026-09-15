--[[
	MatchStateService — tracks whether the arena is currently in use.
	Shared module (ReplicatedStorage) so GameManager and MatchmakingService stay decoupled.
]]

local MatchStateService = {}

local arenaBusy = false
local onArenaFreeCallback = nil

function MatchStateService.setArenaBusy(busy)
	arenaBusy = busy == true
	if not arenaBusy and onArenaFreeCallback then
		onArenaFreeCallback()
	end
end

function MatchStateService.isArenaBusy()
	return arenaBusy
end

function MatchStateService.onArenaFree(callback)
	onArenaFreeCallback = callback
end

return MatchStateService
