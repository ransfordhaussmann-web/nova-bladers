local MODES = {
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
