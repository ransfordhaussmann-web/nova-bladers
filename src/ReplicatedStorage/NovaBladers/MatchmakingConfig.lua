--[[
	MatchmakingConfig — queue timing and UI constants.
]]

local MatchmakingConfig = {
	-- FFA: start match after this many seconds once minPlayers are in queue
	FILL_TIMEOUT_SEC = 12,

	-- How often to push queue position updates to clients
	QUEUE_TICK_SEC = 0.5,

	-- Priority order when arena frees up (first mode with a ready queue wins)
	MODE_PRIORITY = { "training", "pvp", "ffa" },
}

return MatchmakingConfig
