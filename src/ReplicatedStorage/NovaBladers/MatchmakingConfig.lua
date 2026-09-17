--[[
	MatchmakingConfig — Queue-Zeitlimits und Status-Labels.
]]

local MatchmakingConfig = {
	FFA_FILL_TIMEOUT = 12,
	ARENA_BUSY_POLL = 1,
	QUEUE_STATUS = {
		WAITING = "waiting",
		PENDING = "pending",
		STARTING = "starting",
	},
}

return MatchmakingConfig
