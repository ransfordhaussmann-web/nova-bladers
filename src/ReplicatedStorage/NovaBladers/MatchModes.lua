local MODES = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "2–6 Spieler — Free-for-All",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local MatchModes = {}

function MatchModes.get(modeId)
	return MODES[modeId]
end

function MatchModes.all()
	return MODES
end

return MatchModes
