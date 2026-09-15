local MatchmakingConfig = {
	-- FFA: start with whoever is queued after this timeout once minPlayers is met
	FFA_FILL_TIMEOUT = 12,

	-- Retry pending starts when the arena frees up
	ARENA_BUSY_POLL = 0.5,
}

return MatchmakingConfig
