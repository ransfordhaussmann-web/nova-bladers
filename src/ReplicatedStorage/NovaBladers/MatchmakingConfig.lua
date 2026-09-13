local MatchmakingConfig = {
	-- Seconds to wait for more players before starting FFA with whoever is queued
	FFA_FILL_TIMEOUT = 12,

	-- How often queue status is pushed to clients (seconds)
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Minimum hold time before a solo training player starts
	TRAINING_INSTANT_START = true,
}

return MatchmakingConfig
