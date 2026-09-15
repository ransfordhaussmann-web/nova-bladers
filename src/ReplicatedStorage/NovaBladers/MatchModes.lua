local MatchModes = {
	Training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
	},
	PvP = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
	},
	FFA = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
	},
}

local byId = {}
for _, mode in MatchModes do
	byId[mode.id] = mode
end

function MatchModes.get(id)
	return byId[id]
end

function MatchModes.all()
	return { MatchModes.Training, MatchModes.PvP, MatchModes.FFA }
end

return MatchModes
