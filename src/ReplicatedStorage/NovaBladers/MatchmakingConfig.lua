--[[
	MatchmakingConfig — queue timing and limits.
]]

local MatchmakingConfig = {
	-- FFA: wait up to this many seconds for more players before starting
	FFA_FILL_TIMEOUT = 12,

	-- How often to push queue status to clients
	QUEUE_UPDATE_INTERVAL = 0.5,

	-- Portal / quick-match uses auto mode when no pad is chosen
	AUTO_MODE = true,
}

return MatchmakingConfig
