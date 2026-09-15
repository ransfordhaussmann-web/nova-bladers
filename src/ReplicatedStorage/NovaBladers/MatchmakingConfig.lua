--[[
	MatchmakingConfig — Queue-Zeitlimits und Status-Labels.
]]

local MatchmakingConfig = {
	FFA_FILL_TIMEOUT = 12,
	PVP_WAIT_TIMEOUT = 30,
	QUEUE_TICK_INTERVAL = 0.5,
	STARTING_DELAY = 1.5,

	STATUS = {
		WAITING = "waiting",
		FILLING = "filling",
		PENDING = "pending",
		STARTING = "starting",
	},
}

return MatchmakingConfig
