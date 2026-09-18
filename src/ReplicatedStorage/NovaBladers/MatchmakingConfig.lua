local MatchmakingConfig = {
	-- How often queue members receive countdown updates while filling.
	FILL_TICK_INTERVAL = 1,

	-- Recommended mode when joining via portal / quick-match without a pad.
	recommendMode = function(playerCount)
		if playerCount >= 3 then
			return "ffa"
		elseif playerCount == 2 then
			return "pvp"
		end
		return "training"
	end,
}

return MatchmakingConfig
