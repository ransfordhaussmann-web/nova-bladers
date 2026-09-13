local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local tickConnection = nil
local onQueueChange = nil

local function initQueues()
	for _, mode in MatchModes.eachOrdered() do
		queues[mode.id] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillDeadline = nil
	end
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if GameMatchState.isBusy() then
		return "pending"
	end
	if count >= mode.maxPlayers then
		return "ready"
	end
	if modeId == "ffa" and count >= mode.minPlayers and queue.fillDeadline then
		local remaining = math.max(0, queue.fillDeadline - os.clock())
		if remaining <= 0 then
			return "ready"
		end
		return "filling"
	end
	if count >= mode.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = queues[entry.modeId]
	local position = 0
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local fillRemaining = nil
	if entry.modeId == "ffa" and queue.fillDeadline then
		fillRemaining = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		position = position,
		queued = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(entry.modeId),
		arenaBusy = GameMatchState.isBusy(),
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueueUpdate()
	for queuedPlayer, _ in playerQueue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer))
		end
	end
end

local function notifyPlayer(player)
	if player.Parent and playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end

	if #queue.players < MatchModes.get(modeId).minPlayers then
		queue.fillDeadline = nil
	end

	return picked
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end
	if modeId ~= "ffa" and count >= mode.minPlayers then
		return true
	end
	return false
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode or not canStartMode(modeId) then
		return false
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId].players, player)
			playerQueue[player] = { modeId = modeId }
		end
		return false
	end

	GameMatchState.setBusy(true)
	broadcastQueueUpdate()
	Bindables.MatchReady:Fire(players, modeId)
	return true
end

local function tryStartAnyMatch()
	for _, mode in MatchModes.eachOrdered() do
		if tryStartMatch(mode.id) then
			return true
		end
	end
	return false
end

local function ensureFfaFillTimer(modeId)
	if modeId ~= "ffa" then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue.players >= mode.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end
end

function MatchmakingService.setOnQueueChange(callback)
	onQueueChange = callback
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = { modeId = modeId }
	ensureFfaFillTimer(modeId)

	if onQueueChange then
		onQueueChange(player, "join", modeId)
	end

	notifyPlayer(player)
	broadcastQueueUpdate()

	if not GameMatchState.isBusy() then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return false
	end

	removeFromQueueList(player, entry.modeId)
	playerQueue[player] = nil

	if onQueueChange then
		onQueueChange(player, "leave", entry.modeId)
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	broadcastQueueUpdate()
	tryStartAnyMatch()
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if tickConnection then
		tickConnection:Disconnect()
	end

	local lastTick = 0
	tickConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < MatchmakingConfig.QUEUE_TICK_INTERVAL then
			return
		end
		lastTick = now

		if GameMatchState.isBusy() then
			return
		end

		for _, mode in MatchModes.eachOrdered() do
			if canStartMode(mode.id) then
				tryStartMatch(mode.id)
				break
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
