--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
]]

local MODES = {
	{
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	{
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 30,
	},
	{
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local byId = {}
for _, mode in MODES do
	byId[mode.id] = mode
end

local MatchModes = {}

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.all()
	return MODES
end

return MatchModes
