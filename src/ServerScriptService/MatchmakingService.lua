local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local pendingRetryTask = nil
local callbacks = {}

local function getOrCreateQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
			fillTask = nil,
		}
	end
	return queues[modeId]
end

local function cancelFillTimer(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	if queue.fillTask then
		task.cancel(queue.fillTask)
		queue.fillTask = nil
	end
	queue.fillDeadline = nil
end

local function buildQueuePayload(modeId, player)
	local queue = getOrCreateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local secondsLeft = nil
	if queue.fillDeadline then
		secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	local status = "waiting"
	if player and pendingMatch then
		for _, p in pendingMatch.players do
			if p == player then
				status = "pending"
				break
			end
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		secondsLeft = secondsLeft,
		status = status,
		inQueue = player ~= nil and playerQueue[player] == modeId,
	}
end

local function sendQueueUpdate(player, modeId)
	if not player.Parent then
		return
	end
	local payload = buildQueuePayload(modeId, player)
	if payload then
		QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local queue = getOrCreateQueue(modeId)
	for _, player in queue.players do
		sendQueueUpdate(player, modeId)
	end
	if pendingMatch and pendingMatch.modeId == modeId then
		for _, player in pendingMatch.players do
			sendQueueUpdate(player, modeId)
		end
	end
end

local function clearPlayerQueueState(player, broadcastModeId)
	local modeId = playerQueue[player]
	playerQueue[player] = nil

	if modeId then
		local queue = queues[modeId]
		if queue then
			for i, queuedPlayer in queue.players do
				if queuedPlayer == player then
					table.remove(queue.players, i)
					break
				end
			end
			if #queue.players < MatchModes.get(modeId).minPlayers then
				cancelFillTimer(modeId)
			end
		end
		if broadcastModeId ~= false then
			broadcastQueue(modeId)
		end
	end
end

local function removePendingPlayer(player)
	if not pendingMatch then
		return false
	end
	for i, p in pendingMatch.players do
		if p == player then
			table.remove(pendingMatch.players, i)
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
			return true
		end
	end
	return false
end

local function reservePlayers(modeId, playerList)
	for _, player in playerList do
		clearPlayerQueueState(player, false)
	end
	cancelFillTimer(modeId)
	broadcastQueue(modeId)
end

local function tryLaunchReserved(modeId, playerList)
	if #playerList == 0 then
		return
	end

	reservePlayers(modeId, playerList)

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		for _, player in playerList do
			sendQueueUpdate(player, modeId)
		end
		MatchmakingService.schedulePendingRetry()
		return
	end

	for _, player in playerList do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(playerList)
end

function MatchmakingService.schedulePendingRetry()
	if pendingRetryTask then
		return
	end
	pendingRetryTask = task.delay(MatchmakingConfig.PENDING_RETRY_INTERVAL, function()
		pendingRetryTask = nil
		MatchmakingService.tryStartPending()
	end)
end

function MatchmakingService.tryStartPending()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		if pendingMatch and MatchStateService.isArenaBusy() then
			MatchmakingService.schedulePendingRetry()
		end
		return
	end

	local match = pendingMatch
	pendingMatch = nil

	for _, player in match.players do
		if player.Parent and callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	local readyPlayers = {}
	for _, player in match.players do
		if player.Parent then
			table.insert(readyPlayers, player)
		end
	end

	if #readyPlayers > 0 then
		MatchReady:Fire(readyPlayers)
	end
end

local function startMatchFromQueue(modeId)
	local queue = getOrCreateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or #queue.players < mode.minPlayers then
		return
	end

	cancelFillTimer(modeId)

	local count = math.min(#queue.players, mode.maxPlayers)
	local playerList = {}
	for i = 1, count do
		table.insert(playerList, queue.players[i])
	end

	tryLaunchReserved(modeId, playerList)
end

local function scheduleFillTimer(modeId)
	local queue = getOrCreateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 or queue.fillTask then
		return
	end
	if #queue.players < mode.minPlayers then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	queue.fillTask = task.delay(mode.fillTimeout, function()
		queue.fillTask = nil
		queue.fillDeadline = nil
		startMatchFromQueue(modeId)
	end)
	broadcastQueue(modeId)
end

local function evaluateQueue(modeId)
	local queue = getOrCreateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if #queue.players >= mode.maxPlayers then
		startMatchFromQueue(modeId)
		return
	end

	if #queue.players >= mode.minPlayers then
		if mode.fillTimeout <= 0 then
			startMatchFromQueue(modeId)
		else
			scheduleFillTimer(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if callbacks.getPhase and callbacks.getPhase(player) ~= "hub" then
		return
	end

	if pendingMatch then
		for _, p in pendingMatch.players do
			if p == player then
				return
			end
		end
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player, modeId)
		return
	end

	clearPlayerQueueState(player, false)

	local queue = getOrCreateQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	evaluateQueue(modeId)

	if callbacks.onQueueChange then
		callbacks.onQueueChange()
	end
end

function MatchmakingService.leaveQueue(player)
	if removePendingPlayer(player) then
		QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "idle",
		})
		if callbacks.onQueueChange then
			callbacks.onQueueChange()
		end
		return
	end

	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	clearPlayerQueueState(player, true)
	QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "idle",
	})

	if callbacks.onQueueChange then
		callbacks.onQueueChange()
	end
end

function MatchmakingService.getPlayerQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	MatchmakingService.tryStartPending()
end

function MatchmakingService.onPlayerRemoving(player)
	removePendingPlayer(player)
	clearPlayerQueueState(player, true)
	if callbacks.onQueueChange then
		callbacks.onQueueChange()
	end
end

function MatchmakingService.init(options)
	callbacks = options or {}

	MatchStateService.onArenaFreed(function()
		MatchmakingService.tryStartPending()
	end)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if options.hub then
		options.hub.portalPrompt.Triggered:Connect(function(player)
			local modeId = options.getActiveModeId and options.getActiveModeId() or "training"
			MatchmakingService.joinQueue(player, modeId)
		end)

		for _, pad in options.hub.modePads do
			local padModeId = pad.config.id
			if pad.prompt then
				pad.prompt.Triggered:Connect(function(player)
					MatchmakingService.joinQueue(player, padModeId)
				end)
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for _, modeId in MatchModes.ORDER do
				if queues[modeId] and #queues[modeId].players > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
