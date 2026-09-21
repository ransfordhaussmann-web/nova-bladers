local MatchmakingConfig = {
	-- FFA: start with whoever is queued after this timeout (min 2 players)
	FFA_FILL_TIMEOUT = 12,

	-- How often queued players receive queue snapshots
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Priority when multiple modes can start after arena frees up
	START_PRIORITY = { "pvp", "ffa", "training" },
}

return MatchmakingConfig
