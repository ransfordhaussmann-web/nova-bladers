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

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.getAll()
	return { MatchModes.Training, MatchModes.PvP, MatchModes.FFA }
end

function MatchModes.isValid(modeId)
	return byId[modeId] ~= nil
end

return MatchModes
