local MatchModes = {
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
		fillTimeout = 0,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	local list = {}
	for _, mode in pairs(MatchModes) do
		if type(mode) == "table" and mode.id then
			table.insert(list, mode)
		end
	end
	table.sort(list, function(a, b)
		return a.minPlayers < b.minPlayers
	end)
	return list
end

return MatchModes
