local MatchModes = {}

local MODES = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 45,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.get(modeId)
	return MODES[modeId]
end

function MatchModes.getAll()
	local list = {}
	for _, mode in MODES do
		table.insert(list, mode)
	end
	return list
end

function MatchModes.isValid(modeId)
	return MODES[modeId] ~= nil
end

return MatchModes
