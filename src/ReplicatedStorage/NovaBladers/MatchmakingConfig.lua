local MatchmakingConfig = {
	-- Seconds to wait for more FFA players after minimum is reached.
	FFA_FILL_TIMEOUT = 12,

	-- Default mode when joining via portal or quick-match button.
	AUTO_MODE_BY_PLAYER_COUNT = {
		{ minCount = 3, modeId = "ffa" },
		{ minCount = 2, modeId = "pvp" },
		{ minCount = 1, modeId = "training" },
	},
}

function MatchmakingConfig.resolveAutoMode(playerCount)
	for _, rule in MatchmakingConfig.AUTO_MODE_BY_PLAYER_COUNT do
		if playerCount >= rule.minCount then
			return rule.modeId
		end
	end
	return "training"
end

return MatchmakingConfig
