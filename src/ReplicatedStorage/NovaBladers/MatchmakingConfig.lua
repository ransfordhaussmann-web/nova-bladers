--[[
	MatchmakingConfig — player counts and fill timeouts per queue mode.
]]

local MatchmakingConfig = {
	MODES = {
		training = {
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = 0,
		},
		pvp = {
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = 0,
		},
		ffa = {
			minPlayers = 3,
			maxPlayers = 6,
			fillTimeout = 12,
		},
	},

	QUEUE_BROADCAST_INTERVAL = 0.5,
	PAD_TOUCH_DEBOUNCE = 1.5,
}

return MatchmakingConfig
