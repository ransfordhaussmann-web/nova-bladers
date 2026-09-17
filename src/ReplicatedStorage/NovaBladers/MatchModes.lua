--[[
	MatchModes — Spielmodi für die Matchmaking-Queue.
]]

local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		startImmediately = true,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		startImmediately = false,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 3,
		maxPlayers = 6,
		startImmediately = false,
		fillTimeout = 12,
	},
}

local ordered = { "training", "pvp", "ffa" }

function MatchModes.get(id)
	return MatchModes[id]
end

function MatchModes.all()
	local list = {}
	for _, id in ordered do
		table.insert(list, MatchModes[id])
	end
	return list
end

function MatchModes.getDefaultForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
