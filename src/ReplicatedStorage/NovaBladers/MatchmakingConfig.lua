local MatchmakingConfig = {
	-- FFA: wait up to this many seconds for more players after minimum is met
	FFA_FILL_TIMEOUT = 12,

	-- How often to push queue status to clients while waiting
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Retry pending starts after arena frees up
	ARENA_RETRY_DELAY = 0.35,
}

return MatchmakingConfig
