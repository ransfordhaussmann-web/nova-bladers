--[[
	MatchmakingConfig — timeouts and queue behaviour.
]]

local MatchmakingConfig = {
	-- How long to wait after the first player joins before starting a solo training match.
	TRAINING_SOLO_DELAY = 1,

	-- Poll interval while waiting for arena to free up.
	PENDING_POLL_INTERVAL = 0.5,

	-- Recommended mode thresholds (player count in server).
	RECOMMEND_FFA_AT = 3,
	RECOMMEND_PVP_AT = 2,
}

return MatchmakingConfig
