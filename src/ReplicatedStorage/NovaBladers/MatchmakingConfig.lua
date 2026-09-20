local MatchModes = require(script.Parent.MatchModes)

local MatchmakingConfig = {
	MODES = {
		[MatchModes.TRAINING] = {
			id = MatchModes.TRAINING,
			label = "Training",
			desc = "1 Spieler — Dummy-Gegner",
			minPlayers = 1,
			maxPlayers = 1,
			fillTimeout = 0,
		},
		[MatchModes.PVP] = {
			id = MatchModes.PVP,
			label = "1v1 PvP",
			desc = "2 Spieler — Duell",
			minPlayers = 2,
			maxPlayers = 2,
			fillTimeout = 0,
		},
		[MatchModes.FFA] = {
			id = MatchModes.FFA,
			label = "FFA",
			desc = "2–6 Spieler — Free-for-All",
			minPlayers = 2,
			maxPlayers = 6,
			fillTimeout = 12,
		},
	},
}

function MatchmakingConfig.get(modeId)
	return MatchmakingConfig.MODES[modeId]
end

return MatchmakingConfig
