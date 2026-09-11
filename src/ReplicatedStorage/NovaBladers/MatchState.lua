local MatchmakingConfig = require(script.Parent.MatchmakingConfig)

local MatchState = {}

MatchState.Status = {
	Idle = "idle",
	Waiting = "waiting",
	Pending = "pending",
	Starting = "starting",
}

function MatchState.getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

function MatchState.buildQueueUpdate(player, modeId, queueSize, arenaBusy, fillDeadline)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return { inQueue = false, status = MatchState.Status.Idle }
	end

	local status = MatchState.Status.Waiting
	if arenaBusy then
		status = MatchState.Status.Pending
	end
	if queueSize >= mode.minPlayers and not arenaBusy then
		status = MatchState.Status.Starting
	end

	local fillTimeLeft = nil
	if fillDeadline and mode.fillTimeout then
		fillTimeLeft = math.max(0, math.ceil(fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
		arenaBusy = arenaBusy,
	}
end

function MatchState.buildIdleUpdate()
	return { inQueue = false, status = MatchState.Status.Idle }
end

return MatchState
