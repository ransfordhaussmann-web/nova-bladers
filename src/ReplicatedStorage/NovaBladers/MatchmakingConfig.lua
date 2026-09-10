local MatchmakingConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			desc = "1 Spieler — Dummy-Gegner",
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = 0,
			color = Color3.fromRGB(100, 180, 255),
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			desc = "2 Spieler — Duell",
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = 30,
			color = Color3.fromRGB(255, 140, 80),
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			desc = "3–6 Spieler — Free-for-All",
			minPlayers = 3,
			maxPlayers = 6,
			fillTimeout = 12,
			color = Color3.fromRGB(180, 100, 255),
		},
	},
}

function MatchmakingConfig.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

return MatchmakingConfig
