--[[
	MatchModes — queue mode definitions for Training, 1v1 PvP, and FFA.
]]

local MatchModes = {
	Training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
		fillTimeout = 0,
	},
	PvP = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		fillTimeout = 0,
	},
	FFA = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 3,
		maxPlayers = 6,
		fillTimeout = 12,
	},
}

local byId = {}
for _, mode in MatchModes do
	byId[mode.id] = mode
end

function MatchModes.get(modeId)
	return byId[modeId]
end

function MatchModes.getAll()
	return MatchModes
end

function MatchModes.resolveQuickMatch(playerCount)
	if playerCount >= 3 then
		return MatchModes.FFA
	elseif playerCount == 2 then
		return MatchModes.PvP
	end
	return MatchModes.Training
end

return MatchModes
