local Players = game:GetService("Players")

local MatchModes = {}

MatchModes.MODES = {
	training = {
		id = "training",
		label = "Training",
		desc = "1 Spieler — Dummy-Gegner",
		minPlayers = 1,
		maxPlayers = 1,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		desc = "2 Spieler — Duell",
		minPlayers = 2,
		maxPlayers = 2,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		desc = "2–6 Spieler — Free-for-All",
		minPlayers = 2,
		maxPlayers = 6,
	},
}

function MatchModes.getMode(modeId)
	return MatchModes.MODES[modeId]
end

function MatchModes.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	end
	if count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchModes.getModeLabel(modeId)
	local mode = MatchModes.getMode(modeId)
	return mode and mode.label or "Unbekannt"
end

return MatchModes
