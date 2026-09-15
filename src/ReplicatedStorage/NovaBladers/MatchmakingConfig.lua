local MatchmakingConfig = {
	-- How often to re-check queues while players are waiting
	TICK_INTERVAL = 0.5,

	-- Brief pause before Bey selection after match is assigned
	START_DELAY = 0.35,

	-- Status text shown while arena is occupied
	PENDING_MESSAGE = "Arena belegt — du bist als Nächster dran",
	WAITING_MESSAGE = "Warte auf weitere Spieler…",
	STARTING_MESSAGE = "Match startet!",
}

return MatchmakingConfig
