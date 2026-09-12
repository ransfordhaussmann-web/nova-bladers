local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			minPlayers = 1,
			maxPlayers = 1,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			minPlayers = 2,
			maxPlayers = 2,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			minPlayers = 3,
			maxPlayers = 6,
			fillTimeout = 12,
		},
	},

	STATUS = {
		Idle = "idle",
		Queued = "queued",
		Pending = "pending",
		Starting = "starting",
	},
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingConfig.suggestModeForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingConfig
