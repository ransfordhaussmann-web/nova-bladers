local MatchmakingConfig = {
	-- How often queue snapshots are pushed to clients (seconds)
	QUEUE_UPDATE_INTERVAL = 0.5,

	-- Status strings shown in the queue UI
	STATUS = {
		WAITING = "waiting",
		PENDING = "pending",
		STARTING = "starting",
	},
}

return MatchmakingConfig
