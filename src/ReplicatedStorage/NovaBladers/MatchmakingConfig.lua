local MatchmakingConfig = {
	-- How often queued clients receive position updates (seconds)
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Short delay before starting a match after requirements are met
	MATCH_START_DELAY = 1,

	-- Portal / quick-match uses recommended mode from online player count
	AUTO_MODE = true,
}

return MatchmakingConfig
