local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(script.Parent.MatchState)

local MatchmakingManager = {}

local queues = {}
local playerQueue = {}
local pendingPlayers = {}
local fillTokens = {}
local fillTimerActive = {}
local onMatchReady = nil
local onPlayersEnterArena = nil
local broadcastUpdate = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	pendingPlayers[player] = nil
end

local function buildQueuePayload(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
		arenaBusy = MatchState.isBusy(),
	}
end

local function sendUpdate(player)
	local modeId = playerQueue[player] or pendingPlayers[player]
	if not modeId then
		broadcastUpdate(player, nil)
		return
	end

	local payload = buildQueuePayload(modeId)
	payload.pending = pendingPlayers[player] ~= nil
	broadcastUpdate(player, payload)
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendUpdate(queuedPlayer)
	end
	for player, pendingModeId in pendingPlayers do
		if pendingModeId == modeId and player.Parent then
			sendUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimerActive[modeId] = false
end

local function startFillTimer(modeId)
	if fillTimerActive[modeId] then
		return
	end

	local mode = getModeConfig(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	fillTimerActive[modeId] = true
	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		fillTimerActive[modeId] = false
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingManager.tryStartMatch(modeId)
	end)
end

function MatchmakingManager.tryStartMatch(modeId)
	if MatchState.isBusy() then
		return false
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	local queue = queues[modeId]
	local readyCount = 0
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			readyCount += 1
		end
	end

	if readyCount < mode.minPlayers then
		return false
	end

	if readyCount < mode.maxPlayers and readyCount >= mode.minPlayers and mode.fillTimeout > 0 then
		if not fillTimerActive[modeId] then
			startFillTimer(modeId)
		end
		return false
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and #matchPlayers < mode.maxPlayers then
			table.insert(matchPlayers, queuedPlayer)
		end
	end

	if #matchPlayers < mode.minPlayers then
		return false
	end

	for _, matchPlayer in matchPlayers do
		removeFromQueue(matchPlayer)
	end

	MatchState.setBusy()

	if onPlayersEnterArena then
		onPlayersEnterArena(matchPlayers)
	end

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end

	return true
end

local function flushPending()
	if MatchState.isBusy() then
		return
	end

	for player, modeId in pendingPlayers do
		if player.Parent then
			pendingPlayers[player] = nil
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		else
			pendingPlayers[player] = nil
		end
	end

	for modeId in MatchmakingConfig.MODES do
		MatchmakingManager.tryStartMatch(modeId)
	end

	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdates(modeId)
	end
end

function MatchmakingManager.joinQueue(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] or pendingPlayers[player] then
		MatchmakingManager.leaveQueue(player)
	end

	if MatchState.isBusy() then
		pendingPlayers[player] = modeId
		sendUpdate(player)
		return true, "pending"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendUpdate(player)
	broadcastQueueUpdates(modeId)

	if #queues[modeId] >= mode.minPlayers then
		if mode.fillTimeout > 0 and #queues[modeId] < mode.maxPlayers then
			startFillTimer(modeId)
		else
			MatchmakingManager.tryStartMatch(modeId)
		end
	end

	return true, "queued"
end

function MatchmakingManager.leaveQueue(player)
	local modeId = playerQueue[player] or pendingPlayers[player]
	removeFromQueue(player)

	if modeId then
		cancelFillTimer(modeId)
		broadcastQueueUpdates(modeId)
		MatchmakingManager.tryStartMatch(modeId)
	end

	broadcastUpdate(player, nil)
	return true
end

function MatchmakingManager.onMatchEnded()
	MatchState.setIdle()
	flushPending()
end

function MatchmakingManager.getQueueMode(player)
	return playerQueue[player] or pendingPlayers[player]
end

function MatchmakingManager.isQueued(player)
	return playerQueue[player] ~= nil or pendingPlayers[player] ~= nil
end

function MatchmakingManager.onPlayerRemoving(player)
	MatchmakingManager.leaveQueue(player)
end

function MatchmakingManager.init(options)
	initQueues()
	onMatchReady = options.onMatchReady
	onPlayersEnterArena = options.onPlayersEnterArena
	broadcastUpdate = options.broadcastUpdate
end

return MatchmakingManager
