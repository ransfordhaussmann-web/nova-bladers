local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchmakingService = {}

function MatchmakingService.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchmakingService.getAllModes()
	return MatchmakingConfig.MODES
end

function MatchmakingService.isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

function MatchmakingService.resolveAutoMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.buildQueuePayload(modeId, queueSize, status, fillSecondsLeft)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return { inQueue = false }
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
	}
end

function MatchmakingService.getStatusText(payload)
	if not payload.inQueue then
		return ""
	end

	if payload.status == "pending" then
		return "Arena belegt — warte auf freien Slot..."
	end
	if payload.status == "filling" and payload.fillSecondsLeft then
		return string.format(
			"Start in %ds (%d/%d)",
			payload.fillSecondsLeft,
			payload.players,
			payload.maxPlayers
		)
	end
	if payload.status == "starting" then
		return "Match startet..."
	end

	return string.format("Warte auf Spieler (%d/%d)", payload.players, payload.minPlayers)
end

return MatchmakingService
