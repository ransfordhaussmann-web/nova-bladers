local MatchmakingConfig = {
	-- How often queue snapshots are pushed to clients (seconds)
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Grace period before a solo training queue auto-starts
	TRAINING_START_DELAY = 1.5,

	-- PvP waits briefly for the second player before showing "waiting"
	PVP_PAIR_DELAY = 0.5,

	-- FFA fill timeout is per-mode in MatchModes.fillTimeout
}

return MatchmakingConfig
