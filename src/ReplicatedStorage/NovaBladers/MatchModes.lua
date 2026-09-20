local MatchModes = {
	TRAINING = "training",
	PVP = "pvp",
	FFA = "ffa",
}

local MODE_ORDER = {
	MatchModes.TRAINING,
	MatchModes.PVP,
	MatchModes.FFA,
}

local MODE_LABELS = {
	[MatchModes.TRAINING] = "Training",
	[MatchModes.PVP] = "1v1 PvP",
	[MatchModes.FFA] = "FFA",
}

function MatchModes.getLabel(modeId)
	return MODE_LABELS[modeId] or modeId
end

function MatchModes.isValid(modeId)
	return MODE_LABELS[modeId] ~= nil
end

function MatchModes.getAll()
	return MODE_ORDER
end

return MatchModes
