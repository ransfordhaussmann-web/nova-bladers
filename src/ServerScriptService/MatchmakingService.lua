local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local alive = {}
	for _, player in queue do
		if player.Parent then
			table.insert(alive, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = alive
end

local function queueCount(modeId)
	pruneQueue(modeId)
	return #queues[modeId]
end

local function buildUpdateForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local count = queueCount(modeId)
	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		status = "pending"
	elseif count >= mode.minPlayers and not callbacks.isArenaBusy() then
		status = "starting"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function broadcastQueueUpdate()
	if not callbacks.onQueueUpdate then
		return
	end

	local seen = {}
	for modeId, queue in queues do
		pruneQueue(modeId)
		for _, player in queue do
			if not seen[player] then
				seen[player] = true
				local payload = buildUpdateForPlayer(player)
				if payload then
					callbacks.onQueueUpdate(player, payload)
				end
			end
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local queue = queues[modeId]
	local picked = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	return picked
end

local function startPendingMatch()
	if not pendingMatch then
		return
	end
	if callbacks.isArenaBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	local players = pendingMatch.players
	pendingMatch = nil
	clearFillTimer(modeId)
	broadcastQueueUpdate()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function scheduleFillTimeout(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	clearFillTimer(modeId)
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.init(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	pruneQueue(modeId)

	if pendingMatch then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end

	broadcastQueueUpdate()
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	MatchmakingService.leaveQueue(player)

	playerQueue[player] = modeId
	table.insert(queues[modeId], player)

	broadcastQueueUpdate()
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local count = #queues[modeId]
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		clearFillTimer(modeId)
		local players = popPlayers(modeId, mode.maxPlayers)
		if callbacks.isArenaBusy() then
			pendingMatch = { modeId = modeId, players = players }
			broadcastQueueUpdate()
			return
		end
		if callbacks.onMatchReady then
			callbacks.onMatchReady(players, modeId)
		end
		return
	end

	if mode.fillTimeout > 0 and count >= mode.minPlayers then
		if not fillTimers[modeId] then
			scheduleFillTimeout(modeId)
		end
		return
	end

	if count >= mode.minPlayers then
		clearFillTimer(modeId)
		local players = popPlayers(modeId, count)
		if callbacks.isArenaBusy() then
			pendingMatch = { modeId = modeId, players = players }
			broadcastQueueUpdate()
			return
		end
		if callbacks.onMatchReady then
			callbacks.onMatchReady(players, modeId)
		end
	end
end

function MatchmakingService.onArenaFreed()
	startPendingMatch()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMatch(modeId)
	end
end

return MatchmakingService
