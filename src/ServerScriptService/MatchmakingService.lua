local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local onMatchReady = nil
local onQueueChanged = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
	}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	local queue = queues[previousMode]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players == 0 then
		queue.fillDeadline = nil
	end

	playerQueue[player] = nil
	return previousMode
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = getMode(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue.players,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		pending = arenaBusy,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	if not onQueueChanged then
		return
	end

	local queue = queues[modeId]
	for _, player in queue.players do
		onQueueChanged(player, buildQueuePayload(modeId, player))
	end
end

local function tryStartMatch(modeId)
	local queue = queues[modeId]
	local mode = getMode(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 and count < mode.maxPlayers then
		if not queue.fillDeadline or os.clock() < queue.fillDeadline then
			return
		end
	end

	if count > mode.maxPlayers then
		return
	end

	if arenaBusy then
		broadcastQueueUpdate(modeId)
		return
	end

	local roster = table.clone(queue.players)
	for _, player in roster do
		removeFromAllQueues(player)
	end
	queue.fillDeadline = nil

	if onMatchReady then
		onMatchReady(roster, modeId)
	end
end

local function evaluateQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		evaluateQueues()
		return
	end

	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueChanged = callbacks.onQueueChanged
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end

	if arenaBusy and playerQueue[player] == modeId then
		if onQueueChanged then
			onQueueChanged(player, buildQueuePayload(modeId, player))
		end
		return true
	end

	removeFromAllQueues(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #queue.players == 1 then
		queue.fillDeadline = os.clock() + getMode(modeId).fillTimeout
	elseif #queue.players >= getMode(modeId).maxPlayers then
		queue.fillDeadline = nil
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.getActiveModeId(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.tick()
	for modeId, queue in queues do
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.clearPlayer(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
