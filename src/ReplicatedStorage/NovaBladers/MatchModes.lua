local MatchModes = {
	training = {
		id = "training",
		label = "Training",
		minPlayers = 1,
		maxPlayers = 1,
		waitForFill = false,
	},
	pvp = {
		id = "pvp",
		label = "1v1 PvP",
		minPlayers = 2,
		maxPlayers = 2,
		waitForFill = true,
	},
	ffa = {
		id = "ffa",
		label = "FFA",
		minPlayers = 3,
		maxPlayers = 6,
		waitForFill = true,
	},
}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function getDefaultModeForPlayerCount(count)
	if count >= 3 then
		return MatchModes.ffa
	elseif count == 2 then
		return MatchModes.pvp
	end
	return MatchModes.training
end

return {
	Modes = MatchModes,
	getMode = getMode,
	getDefaultModeForPlayerCount = getDefaultModeForPlayerCount,
}
