local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 8,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local ordered = { "training", "pvp", "ffa" }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.resolve(modeId)
	if modeId == "auto" or modeId == nil then
		return nil
	end
	return MatchModes[modeId]
end

function MatchModes.defaultForPlayerCount(count)
	if count >= 3 then
		return MatchModes.ffa
	elseif count == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

function MatchModes.all()
	local list = {}
	for _, id in ordered do
		table.insert(list, MatchModes[id])
	end
	return list
end

return MatchModes
