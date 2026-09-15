--[[
	MatchModes — canonical mode ids for matchmaking queues.
]]

local MatchModes = {
	Training = "training",
	PvP = "pvp",
	FFA = "ffa",
}

local LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function isValid(modeId)
	return modeId == MatchModes.Training
		or modeId == MatchModes.PvP
		or modeId == MatchModes.FFA
end

return {
	Modes = MatchModes,
	LABELS = LABELS,
	isValid = isValid,
}
