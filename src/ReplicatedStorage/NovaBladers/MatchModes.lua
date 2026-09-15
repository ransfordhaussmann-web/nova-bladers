--[[
	MatchModes — Spielmodi für die Matchmaking-Queue.
	Training (1), PvP (2), FFA (3–6 mit Fill-Timeout).
]]

local MatchModes = {}

local MODES = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		instantStart = true,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		instantStart = true,
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

function MatchModes.get(modeId)
	return MODES[modeId]
end

function MatchModes.all()
	local list = {}
	for _, mode in MODES do
		table.insert(list, mode)
	end
	return list
end

function MatchModes.recommendForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
