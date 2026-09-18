--[[
	MatchmakingConfig — shared queue timing and UI labels.
]]

local MatchmakingConfig = {
	FFA_FILL_TIMEOUT = 12,
	QUEUE_RETRY_INTERVAL = 0.5,
	STATUS = {
		WAITING = "waiting",
		PENDING = "pending",
		STARTING = "starting",
	},
}

return MatchmakingConfig
