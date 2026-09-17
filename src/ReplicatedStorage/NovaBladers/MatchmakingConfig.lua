local MatchmakingConfig = {
	-- Wie lange FFA auf weitere Spieler wartet, bevor mit Minimum gestartet wird
	FFA_FILL_TIMEOUT = 12,

	-- Kurze Verzögerung bevor Match nach Queue-Füllung startet
	MATCH_READY_DELAY = 1.5,

	-- Status-Update-Intervall für Queue-UI (Sekunden)
	QUEUE_BROADCAST_INTERVAL = 0.5,
}

return MatchmakingConfig
