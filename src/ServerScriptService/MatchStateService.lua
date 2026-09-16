--[[
	MatchStateService — shared arena-busy flag for matchmaking pending state.
	GameManager registers handlers; MatchmakingService reads isArenaBusy().
]]

local MatchStateService = {}

local handlers = {
	isArenaBusy = function()
		return false
	end,
}

function MatchStateService.register(newHandlers)
	for key, fn in newHandlers do
		handlers[key] = fn
	end
end

function MatchStateService.isArenaBusy()
	return handlers.isArenaBusy()
end

return MatchStateService
