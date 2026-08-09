local MatchmakingConfig = {
	-- Solo: wait for more players before starting Training
	SOLO_MAX_WAIT = 12,
	-- After 2 players: brief window for a 3rd (FFA) before 1v1 starts
	PVP_EXTRA_WAIT = 6,
	-- When 3+ players: short delay so UI can show FFA before match
	FFA_READY_DELAY = 3,
	-- How often the server re-evaluates queue timers
	TICK_INTERVAL = 0.25,
}

return MatchmakingConfig
