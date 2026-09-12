local MatchState = {
	QueueStatus = {
		Searching = "searching",
		Pending = "pending",
		Starting = "starting",
	},
}

function MatchState.isValidMode(modeId, config)
	return config.MODES[modeId] ~= nil
end

function MatchState.getModeLabel(modeId, config)
	local mode = config.MODES[modeId]
	return mode and mode.label or modeId
end

return MatchState
