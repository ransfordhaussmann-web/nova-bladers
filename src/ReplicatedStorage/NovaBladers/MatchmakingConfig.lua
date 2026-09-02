local MatchmakingConfig = {
	-- Max wait when 2 players are queued (hoping a 3rd joins for FFA)
	GATHER_SECONDS = 15,
	-- Solo player starts training after this delay
	SOLO_TRAINING_WAIT = 4,
	-- Short gather when 3+ players are already queued
	FFA_GATHER_SECONDS = 6,
	-- Max players per FFA match
	MAX_FFA_PLAYERS = 8,
	QUEUE_TICK = 0.5,
}

return MatchmakingConfig
