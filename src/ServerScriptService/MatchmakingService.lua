local MatchmakingConfig = require(game:GetService("ReplicatedStorage").NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local callbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
			pending = false,
		}
	end
	return queues[modeId]
end

local function removeFromQueueList(queue, player)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			return true
		end
	end
	return false
end

local function clearFillDeadline(queue)
	queue.fillDeadline = nil
end

local function queueHasPlayer(queue, player)
	for _, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return true
		end
	end
	return false
end

local function buildQueuePayload(modeId, queue)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = #queue.players
	local status = "waiting"
	if queue.pending or arenaBusy then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "full"
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 and queue.fillDeadline then
		status = "starting"
	elseif count >= mode.minPlayers and mode.fillTimeout == 0 then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = mode.fillTimeout,
		fillRemaining = queue.fillDeadline and math.max(0, queue.fillDeadline - os.clock()) or nil,
	}
end

function MatchmakingService.setCallbacks(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId, queue in queues do
		if #queue.players > 0 then
			queue.pending = busy
			MatchmakingService.broadcastQueue(modeId)
			if not busy then
				MatchmakingService.tryStartMatch(modeId)
			end
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueSnapshot(modeId)
	local queue = getQueue(modeId)
	return buildQueuePayload(modeId, queue)
end

function MatchmakingService.broadcastQueue(modeId)
	local queue = getQueue(modeId)
	local payload = buildQueuePayload(modeId, queue)
	for _, player in queue.players do
		if player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, payload)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	removeFromQueueList(queue, player)
	playerQueue[player] = nil
	clearFillDeadline(queue)

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, nil)
	end
	MatchmakingService.broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.MODES[modeId] then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerQueue[player] == modeId then
		MatchmakingService.broadcastQueue(modeId)
		return modeId
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)

	if #queue.players >= mode.maxPlayers then
		return nil
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	queue.pending = arenaBusy

	MatchmakingService.broadcastQueue(modeId)
	MatchmakingService.tryStartMatch(modeId)

	return modeId
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		local queue = getQueue(modeId)
		if #queue.players > 0 then
			queue.pending = true
			MatchmakingService.broadcastQueue(modeId)
		end
		return
	end

	local queue = getQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		MatchmakingService.startMatch(modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			MatchmakingService.broadcastQueue(modeId)
			task.spawn(function()
				while queue.fillDeadline do
					task.wait(1)
					if not queue.fillDeadline then
						break
					end
					MatchmakingService.broadcastQueue(modeId)
					if os.clock() >= queue.fillDeadline then
						break
					end
				end
			end)
			task.delay(mode.fillTimeout, function()
				local activeQueue = getQueue(modeId)
				if activeQueue.fillDeadline and #activeQueue.players >= mode.minPlayers then
					MatchmakingService.startMatch(modeId)
				end
			end)
		end
		return
	end

	MatchmakingService.startMatch(modeId)
end

function MatchmakingService.startMatch(modeId)
	local queue = getQueue(modeId)
	if #queue.players == 0 then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local matched = {}
	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matched, queue.players[i])
	end

	for _, player in matched do
		playerQueue[player] = nil
	end

	queue.players = {}
	clearFillDeadline(queue)
	queue.pending = false

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, matched)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
