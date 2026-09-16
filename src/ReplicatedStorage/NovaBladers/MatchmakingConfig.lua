local MatchmakingConfig = {
	-- How often queue status is pushed to clients (seconds).
	QUEUE_BROADCAST_INTERVAL = 0.5,

	-- Default mode when joining via portal / quick-match without a pad.
	DEFAULT_MODE = "training",

	-- Status strings shown in the queue UI.
	STATUS = {
		searching = "Suche Mitspieler…",
		pending = "Arena belegt — warte…",
		ready = "Match startet gleich…",
	},
}

return MatchmakingConfig
