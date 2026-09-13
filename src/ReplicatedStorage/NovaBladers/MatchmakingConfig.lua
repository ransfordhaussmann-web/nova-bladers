--[[
	MatchmakingConfig — queue timing and UI copy.
]]

local MatchmakingConfig = {
	FFA_FILL_TIMEOUT = 12,
	QUEUE_BROADCAST_DEBOUNCE = 0.25,
}

MatchmakingConfig.STATUS = {
	Idle = "idle",
	Queued = "queued",
	Pending = "pending",
	Starting = "starting",
}

return MatchmakingConfig
