local MatchModes = {}

MatchModes.list = {
	{
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		instantStart = true,
	},
	{
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		instantStart = true,
	},
	{
		id = "ffa",
		label = "FFA",
		desc = "2–6 Spieler — Free-for-All",
		minPlayers = 2,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

function MatchModes.getById(id)
	for _, mode in MatchModes.list do
		if mode.id == id then
			return mode
		end
	end
	return MatchModes.list[1]
end

return MatchModes
