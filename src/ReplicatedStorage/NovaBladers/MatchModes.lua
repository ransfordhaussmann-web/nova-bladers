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
		desc = "2–6 Spieler — Free-for-All",
		minPlayers = 2,
		maxPlayers = 6,
		instantStart = false,
	},
}

local ordered = { MatchModes.training, MatchModes.pvp, MatchModes.ffa }

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.all()
	return ordered
end

function MatchModes.resolveQuickMatch(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchModes
