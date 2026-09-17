local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = nil,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = nil,
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

local ORDER = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	return ORDER
end

function MatchModes.recommendForServerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
