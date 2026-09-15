--[[
	MatchmakingConfig — queue timing and UI copy.
]]

local MatchmakingConfig = {
	FFA_FILL_TIMEOUT = 12,
	QUEUE_BROADCAST_INTERVAL = 0.4,
	PENDING_RETRY_INTERVAL = 1.5,

	STATUS = {
		IDLE = "idle",
		QUEUED = "queued",
		PENDING = "pending",
		STARTING = "starting",
	},

	LABELS = {
		training = "Training",
		pvp = "1v1 PvP",
		ffa = "FFA",
	},
}

return MatchmakingConfig
