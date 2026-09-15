local MatchmakingConfig = {
	-- Seconds to wait for more FFA players before starting with whoever is queued
	FFA_FILL_TIMEOUT = 12,

	-- How often to retry starting a match when the arena is still busy
	ARENA_BUSY_POLL = 1,

	-- Max time to wait for a second PvP player before cancelling the solo queue entry
	PVP_WAIT_TIMEOUT = 45,
}

return MatchmakingConfig
