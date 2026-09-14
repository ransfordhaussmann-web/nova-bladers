local MatchmakingConfig = {
	-- FFA starts when min reached and fill timer expires, or when max is hit
	FFA_FILL_TIMEOUT = 12,
	PVP_FILL_TIMEOUT = 45,
	TRAINING_START_DELAY = 0.5,

	-- How often the service re-evaluates queues (seconds)
	TICK_INTERVAL = 0.5,
}

return MatchmakingConfig
