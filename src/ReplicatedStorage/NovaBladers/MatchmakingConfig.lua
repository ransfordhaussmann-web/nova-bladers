--[[
	MatchmakingConfig — shared queue timing and UI copy.
]]

local MatchmakingConfig = {
	QUEUE_POLL_INTERVAL = 0.5,
	PENDING_RETRY_INTERVAL = 1,
	PORTAL_MODE = "auto",
	UI = {
		QUEUED = "In Warteschlange…",
		PENDING = "Arena belegt — warte…",
		READY = "Match startet…",
	},
}

return MatchmakingConfig
