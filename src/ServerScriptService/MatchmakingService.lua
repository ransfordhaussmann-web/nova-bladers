local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {}
local playerQueue = {}
local pendingModes = {}
local fillTimers = {}
local hubCallbacks = {}

local function createQueue(modeId)
	return {
		modeId = modeId,
		players = {},
		pending = false,
		fillStartedAt = nil,
	}
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = createQueue(modeId)
	end
	return queues[modeId]
end

local function getPlayerName(player)
	return player.DisplayName or player.Name
end

local function buildQueuePayload(modeId, queue)
	local mode = MatchModes.get(modeId)
	local playerNames = {}
	for _, player in queue.players do
		if player.Parent then
			table.insert(playerNames, getPlayerName(player))
		end
	end

	local status = "waiting"
	if queue.pending or MatchStateService.isBusy() then
		status = "pending"
	elseif #queue.players >= mode.maxPlayers then
		status = "ready"
	elseif #queue.players >= mode.minPlayers and mode.fillTimeout > 0 then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = playerNames,
		count = #playerNames,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = mode.fillTimeout,
		fillRemaining = nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	local payload = buildQueuePayload(modeId, queue)

	if queue.fillStartedAt and queue.modeId then
		local mode = MatchModes.get(modeId)
		if mode.fillTimeout > 0 then
			local elapsed = os.clock() - queue.fillStartedAt
			payload.fillRemaining = math.max(0, math.ceil(mode.fillTimeout - elapsed))
		end
	end

	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue.players == 0 then
		queue.fillStartedAt = nil
		queue.pending = false
		clearFillTimer(modeId)
		pendingModes[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
end

local function setQueuePending(modeId, pending)
	local queue = getQueue(modeId)
	queue.pending = pending
	if pending then
		pendingModes[modeId] = true
	else
		pendingModes[modeId] = nil
	end
	broadcastQueueUpdate(modeId)
end

local function canStartMatch(modeId, queue)
	local mode = MatchModes.get(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout <= 0 then
		return count >= mode.minPlayers
	end

	if not queue.fillStartedAt then
		return false
	end

	return (os.clock() - queue.fillStartedAt) >= mode.fillTimeout
end

local function takeReadyPlayers(modeId)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	local ready = {}

	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		local player = queue.players[1]
		table.remove(queue.players, 1)
		playerQueue[player] = nil
		table.insert(ready, player)
	end

	queue.fillStartedAt = nil
	queue.pending = false
	clearFillTimer(modeId)
	pendingModes[modeId] = nil

	if #queue.players > 0 then
		local remaining = getQueue(modeId)
		local remainingMode = MatchModes.get(modeId)
		if #remaining.players >= remainingMode.minPlayers and remainingMode.fillTimeout > 0 then
			remaining.fillStartedAt = os.clock()
			local token = {}
			fillTimers[modeId] = token
			task.delay(remainingMode.fillTimeout, function()
				if fillTimers[modeId] ~= token then
					return
				end
				MatchmakingService.tryStartMatch(modeId)
			end)
		end
	end

	broadcastQueueUpdate(modeId)
	return ready
end

function MatchmakingService.tryStartMatch(modeId)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)

	if #queue.players == 0 then
		return
	end

	if MatchStateService.isBusy() then
		setQueuePending(modeId, true)
		return
	end

	if not canStartMatch(modeId, queue) then
		if #queue.players >= mode.minPlayers and mode.fillTimeout > 0 and not queue.fillStartedAt then
			queue.fillStartedAt = os.clock()
			local token = {}
			fillTimers[modeId] = token
			broadcastQueueUpdate(modeId)
			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] ~= token then
					return
				end
				MatchmakingService.tryStartMatch(modeId)
			end)
		end
		return
	end

	setQueuePending(modeId, false)
	local readyPlayers = takeReadyPlayers(modeId)
	if #readyPlayers == 0 then
		return
	end

	if hubCallbacks.onMatchReady then
		hubCallbacks.onMatchReady(modeId, readyPlayers)
	end

	MatchReadyBindable:Fire({
		modeId = modeId,
		players = readyPlayers,
	})
end

function MatchmakingService.onArenaFree()
	for modeId in pendingModes do
		setQueuePending(modeId, false)
		MatchmakingService.tryStartMatch(modeId)
	end

	for modeId, queue in queues do
		if #queue.players > 0 and not queue.pending then
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return
	end

	removePlayerFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if hubCallbacks.onJoinQueue then
		hubCallbacks.onJoinQueue(player, modeId)
	end

	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removePlayerFromQueue(player)

	if hubCallbacks.onLeaveQueue then
		hubCallbacks.onLeaveQueue(player)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	hubCallbacks = options or {}
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady

	for _, mode in MatchModes.all() do
		getQueue(mode.id)
	end

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.getRecommendedId(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		task.defer(broadcastAllQueues)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
