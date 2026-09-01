--[[
	MatchConfig — queue sizes and mode metadata for matchmaking.
]]

local MatchConfig = {
	MODES = {
		training = {
			id = "training",
			label = "Training",
			shortLabel = "Training",
			minPlayers = 1,
			maxPlayers = 1,
			gatherDelay = 0,
		},
		pvp = {
			id = "pvp",
			label = "1v1 PvP",
			shortLabel = "1v1",
			minPlayers = 2,
			maxPlayers = 2,
			gatherDelay = 0,
		},
		ffa = {
			id = "ffa",
			label = "FFA",
			shortLabel = "FFA",
			minPlayers = 3,
			maxPlayers = 6,
			gatherDelay = 5,
		},
	},

	MODE_ORDER = { "training", "pvp", "ffa" },
}

function MatchConfig.getMode(modeId)
	return MatchConfig.MODES[modeId]
end

function MatchConfig.isValidMode(modeId)
	return MatchConfig.MODES[modeId] ~= nil
end

return MatchConfig
