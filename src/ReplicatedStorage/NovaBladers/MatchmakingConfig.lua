local MatchmakingConfig = {
	-- FFA: wait up to this many seconds after min players to fill the roster
	FFA_FILL_TIMEOUT = 12,

	-- How often queued players receive status updates
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Brief pause before Bey selection after match is formed
	MATCH_FORM_DELAY = 0.5,
}

return MatchmakingConfig
