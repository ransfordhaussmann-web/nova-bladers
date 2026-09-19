local MatchmakingConfig = {
	-- FFA: start with whoever is queued after this timeout (min 2 players)
	FFA_FILL_TIMEOUT = 12,

	-- How often queue UI gets refreshed while waiting
	QUEUE_UPDATE_INTERVAL = 1,

	-- Brief pause before launching a ready match
	MATCH_START_DELAY = 0.5,
}

return MatchmakingConfig
