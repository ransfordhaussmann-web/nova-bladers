--[[
	MatchmakingConfig — Queue-Zeiten und UI-Texte.
]]

local MatchmakingConfig = {
	QUEUE_POLL_INTERVAL = 0.5,
	ARENA_BUSY_RETRY = 2,
	MAX_PENDING_WAIT = 30,

	STATUS = {
		IDLE = "idle",
		QUEUED = "queued",
		PENDING = "pending",
		STARTING = "starting",
	},
}

return MatchmakingConfig
