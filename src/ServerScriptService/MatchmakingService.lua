local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {}
local playerQueue = {}
local pendingReady = nil
local heartbeat = nil

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function pruneQueuePlayers(queue)
	local alive = {}
	for _, player in queue.players do
		if player.Parent and playerQueue[player] then
			table.insert(alive, player)
		end
	end
	queue.players = alive
end

local function getQueueStatus(modeId, queue)
	local mode = MatchModes.get(modeId)
	local count = #queue.players
	local status = "waiting"
	local fillTimeLeft = nil

	if pendingReady and pendingReady.modeId == modeId then
		status = "pending"
	elseif count >= mode.minPlayers then
		if mode.id == "ffa" and count < mode.maxPlayers and queue.fillDeadline then
			fillTimeLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
			if fillTimeLeft <= 0 then
				status = "starting"
			end
		elseif count >= mode.maxPlayers or (mode.id ~= "ffa" and count >= mode.minPlayers) then
			status = MatchStateService.isBusy() and "pending" or "starting"
		end
	end

	return {
		inQueue = true,
		modeId = mode.id,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local queue = ensureQueue(modeId)
	pruneQueuePlayers(queue)
	Remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId, queue))
end

local function broadcastQueue(modeId)
	for player, queuedModeId in playerQueue do
		if queuedModeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillDeadline = nil
	end

	if pendingReady then
		local valid = {}
		for _, pendingPlayer in pendingReady.players do
			if playerQueue[pendingPlayer] == pendingReady.modeId then
				table.insert(valid, pendingPlayer)
			end
		end
		if #valid < MatchModes.get(pendingReady.modeId).minPlayers then
			pendingReady = nil
		else
			pendingReady.players = valid
		end
	end

	broadcastQueue(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function isQueueReady(modeId, queue)
	local mode = MatchModes.get(modeId)
	pruneQueuePlayers(queue)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if mode.id == "ffa" then
		if count >= mode.maxPlayers then
			return true
		end
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			return true
		end
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + MatchmakingConfig.FILL_TIMEOUT
		end
		return false
	end

	return count >= mode.maxPlayers
end

local function launchMatch(modeId, queue)
	local players = {}
	for _, player in queue.players do
		if player.Parent then
			table.insert(players, player)
		end
	end

	queue.players = {}
	queue.fillDeadline = nil

	for _, player in players do
		playerQueue[player] = nil
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)
	MatchReady:Fire(players, modeId)
end

local function tryStartMatch(modeId)
	local queue = ensureQueue(modeId)
	if not isQueueReady(modeId, queue) then
		broadcastQueue(modeId)
		return
	end

	if MatchStateService.isBusy() then
		pendingReady = {
			modeId = modeId,
			players = table.clone(queue.players),
		}
		broadcastQueue(modeId)
		return
	end

	launchMatch(modeId, queue)
end

local function tryStartPendingOrQueues()
	if MatchStateService.isBusy() then
		return
	end

	if pendingReady then
		local modeId = pendingReady.modeId
		local players = {}
		for _, player in pendingReady.players do
			if player.Parent and playerQueue[player] == modeId then
				table.insert(players, player)
			end
		end
		pendingReady = nil

		if #players >= MatchModes.get(modeId).minPlayers then
			for _, player in players do
				removePlayerFromQueue(player)
			end
			MatchStateService.setBusy(true)
			MatchReady:Fire(players, modeId)
			return
		end
	end

	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
		if MatchStateService.isBusy() then
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerQueue[player] then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= MatchModes.get(modeId).maxPlayers then
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	HubService.setPhase(player, "queue")
	sendQueueUpdate(player)
	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removePlayerFromQueue(player)
	if HubService.getPhase(player) == "queue" then
		HubService.setPhase(player, "hub")
	end
end

local function onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(tryStartPendingOrQueues)
end

local function onQueueTick()
	for _, mode in MatchModes.all() do
		local queue = ensureQueue(mode.id)
		if queue.fillDeadline and #queue.players >= MatchModes.get(mode.id).minPlayers then
			tryStartMatch(mode.id)
		end
	end
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	for _, mode in MatchModes.all() do
		ensureQueue(mode.id)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(onMatchEnded)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if heartbeat then
		heartbeat:Disconnect()
	end
	local lastTick = 0
	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick >= MatchmakingConfig.QUEUE_TICK_INTERVAL then
			lastTick = now
			onQueueTick()
		end
	end)
end

return MatchmakingService
