local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingModeId = nil
local arenaBusy = false

local callbacks = {
	onReady = nil,
	onQueueUpdate = nil,
}

local function getMode(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
		}
	end
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent ~= nil
end

local function queueIndex(queue, player)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		local index = queueIndex(queue, player)
		if index then
			table.remove(queue.players, index)
		end
		if #queue.players == 0 then
			queue.fillToken += 1
		end
	end

	playerQueue[player] = nil
end

local function buildUpdatePayload(modeId, status)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local validPlayers = {}
	for _, player in queue.players do
		if isPlayerValid(player) then
			table.insert(validPlayers, player)
		end
	end
	queue.players = validPlayers

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue.players,
		requiredPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = status == "pending",
	}
end

local function broadcastQueue(modeId, status)
	if not callbacks.onQueueUpdate then
		return
	end

	local payload = buildUpdatePayload(modeId, status)
	for _, player in ensureQueue(modeId).players do
		if isPlayerValid(player) then
			callbacks.onQueueUpdate(player, payload)
		end
	end
end

local function clearQueue(modeId)
	local queue = ensureQueue(modeId)
	queue.players = {}
	queue.fillToken += 1
	pendingModeId = nil
end

local function pullReadyPlayers(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local ready = {}

	for _, player in queue.players do
		if isPlayerValid(player) and #ready < mode.maxPlayers then
			table.insert(ready, player)
		end
	end

	if #ready < mode.minPlayers then
		return nil
	end

	for _, player in ready do
		removeFromQueue(player)
	end

	return ready
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue.players < mode.minPlayers then
		return
	end

	if arenaBusy then
		pendingModeId = modeId
		broadcastQueue(modeId, "pending")
		return
	end

	local players = pullReadyPlayers(modeId)
	if not players or #players == 0 then
		return
	end

	pendingModeId = nil
	arenaBusy = true

	if callbacks.onReady then
		callbacks.onReady(players, modeId)
	end
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local queue = ensureQueue(modeId)
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if #queue.players >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(opts)
	callbacks.onReady = opts.onReady
	callbacks.onQueueUpdate = opts.onQueueUpdate
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processPending()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player)
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, {
			status = "idle",
			modeId = nil,
			modeLabel = nil,
			queueSize = 0,
		})
	end
	broadcastQueue(modeId, "queued")
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode or not isPlayerValid(player) then
		return false
	end

	if playerQueue[player] == modeId then
		return true
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	broadcastQueue(modeId, arenaBusy and "pending" or "queued")

	if #queue.players >= mode.minPlayers then
		tryStartMatch(modeId)
	elseif mode.fillTimeout > 0 and #queue.players == 1 then
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.processPending()
	if arenaBusy then
		return
	end

	if pendingModeId then
		tryStartMatch(pendingModeId)
		return
	end

	for modeId in MatchmakingConfig.MODES do
		local queue = ensureQueue(modeId)
		local mode = getMode(modeId)
		if #queue.players >= mode.minPlayers then
			tryStartMatch(modeId)
			return
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	MatchmakingService.processPending()
end

return MatchmakingService
