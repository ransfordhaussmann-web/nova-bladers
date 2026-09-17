local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyEvent
local callbacks = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local pendingRetryToken = 0

local function makeQueueState()
	return {
		players = {},
		fillToken = 0,
		fillEndsAt = nil,
	}
end

for modeId, mode in MatchModes do
	if typeof(mode) == "table" and mode.id then
		queues[modeId] = makeQueueState()
	end
end

local function getQueue(modeId)
	return queues[modeId]
end

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function isPlayerValid(player)
	return player and player.Parent and callbacks.getPhase and callbacks.getPhase(player) == "hub"
end

local function clearFillTimer(queue)
	queue.fillToken += 1
	queue.fillEndsAt = nil
end

local function getFillSecondsLeft(queue, mode)
	if not queue.fillEndsAt or not mode.fillTimeout then
		return nil
	end
	return math.max(0, math.ceil(queue.fillEndsAt - os.clock()))
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return { inQueue = false }
	end

	local position = table.find(queue.players, player)
	return {
		inQueue = position ~= nil,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue.players,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status or "waiting",
		secondsLeft = getFillSecondsLeft(queue, mode),
	}
end

local function sendQueueUpdate(player, status)
	if not remotes or not player.Parent then
		return
	end
	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueue(modeId, status)
	local queue = getQueue(modeId)
	if not queue then
		return
	end
	for _, player in queue.players do
		sendQueueUpdate(player, status)
	end
end

local function removePlayerFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	if queue then
		local index = table.find(queue.players, player)
		if index then
			table.remove(queue.players, index)
		end
		if #queue.players < getMode(modeId).minPlayers then
			clearFillTimer(queue)
		end
	end

	playerQueue[player] = nil

	if not silent then
		sendQueueUpdate(player)
		broadcastQueue(modeId)
	end
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue or not mode.fillTimeout then
		return
	end

	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillEndsAt = os.clock() + mode.fillTimeout
	broadcastQueue(modeId)

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		queue.fillEndsAt = nil
		MatchmakingService.tryStartMatch(modeId, true)
	end)
end

local function popPlayersForMatch(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return {}
	end

	local matched = {}
	local count = math.min(#queue.players, mode.maxPlayers)
	for i = 1, count do
		table.insert(matched, queue.players[i])
	end

	for i = count, 1, -1 do
		table.remove(queue.players, i)
	end
	clearFillTimer(queue)

	for _, player in matched do
		playerQueue[player] = nil
	end

	return matched
end

local function launchMatch(players, modeId, status)
	for _, player in players do
		sendQueueUpdate(player, status or "starting")
	end

	MatchStateService.setBusy(true)
	for _, player in players do
		if callbacks.enterArena then
			callbacks.enterArena(player)
		end
	end

	matchReadyEvent:Fire(players, modeId)
end

function MatchmakingService.tryStartMatch(modeId, force)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return
	end

	local count = #queue.players
	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" and not force and count < mode.maxPlayers then
		if not queue.fillEndsAt then
			startFillTimer(modeId)
		end
		return
	end

	if count > mode.maxPlayers then
		return
	end

	local players = popPlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	broadcastQueue(modeId)

	if MatchStateService.isBusy() then
		pendingMatch = {
			players = players,
			modeId = modeId,
		}
		for _, player in players do
			sendQueueUpdate(player, "pending")
		end
		MatchmakingService.schedulePendingRetry()
		return
	end

	launchMatch(players, modeId)
end

function MatchmakingService.schedulePendingRetry()
	pendingRetryToken += 1
	local token = pendingRetryToken
	task.delay(MatchmakingConfig.ARENA_PENDING_RETRY, function()
		if token ~= pendingRetryToken then
			return
		end
		MatchmakingService.processPending()
	end)
end

function MatchmakingService.processPending()
	if not pendingMatch or MatchStateService.isBusy() then
		if pendingMatch and MatchStateService.isBusy() then
			MatchmakingService.schedulePendingRetry()
		end
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.players, match.modeId, "starting")
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)
	MatchmakingService.processPending()

	for modeId in queues do
		if queues[modeId] then
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return
	end

	if not MatchModes.isValid(modeId) then
		modeId = callbacks.getActiveModeId and callbacks.getActiveModeId() or "training"
	end

	removePlayerFromQueue(player, true)

	local queue = getQueue(modeId)
	if not queue then
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueue(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyEvent = options.bindables.MatchReady
	callbacks = {
		enterArena = options.enterArena,
		getPhase = options.getPhase,
		getActiveModeId = options.getActiveModeId,
	}

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromQueue(player, true)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
