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
		waitForFill = false,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
		waitForFill = false,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "3–6 Spieler — Free-for-All",
		minPlayers = 3,
		maxPlayers = 6,
		waitForFill = true,
	},
}

function MatchModes.get(modeId)
	return MatchModes[modeId]
end

function MatchModes.getDefaultForPlayerCount(count)
	if count >= 3 then
		return MatchModes.ffa
	elseif count == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return MatchModes
