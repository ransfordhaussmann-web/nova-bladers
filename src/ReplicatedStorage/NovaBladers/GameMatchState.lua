--[[
	GameMatchState — shared arena-busy flag so MatchmakingService can defer starts.
]]

local GameMatchState = {
	arenaBusy = false,
}

return GameMatchState
