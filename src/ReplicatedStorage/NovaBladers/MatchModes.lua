--[[
	MatchModes — queue definitions for Training, 1v1 PvP, and FFA.
]]

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

local ALL = { "training", "pvp", "ffa" }

local byId = {}
for _, modeId in ALL do
	byId[modeId] = MatchModes[modeId]
end

MatchModes.ALL = ALL

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.isValid(modeId)
	return byId[modeId] ~= nil
end

return MatchModes
