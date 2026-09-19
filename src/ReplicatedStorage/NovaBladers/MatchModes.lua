local MatchModes = {
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

local orderedIds = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getOrdered()
	local list = {}
	for _, id in orderedIds do
		table.insert(list, MatchModes[id])
	end
	return list
end

function MatchModes.isValid(modeId)
	return MatchModes[modeId] ~= nil
end

return MatchModes
