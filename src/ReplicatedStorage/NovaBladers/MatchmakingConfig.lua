local MatchmakingConfig = {
	-- How often the server re-checks queues while the arena is busy.
	PENDING_RETRY_INTERVAL = 1.5,

	-- Quick-match prefers FFA when enough players are online.
	QUICK_MATCH_FFA_THRESHOLD = 3,
}

return MatchmakingConfig
