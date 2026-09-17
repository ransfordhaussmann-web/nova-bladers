local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local handlers = {}
local started = false

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
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

local function getQueuePosition(modeId, player)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return i
		end
	end
	return 0
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return {
			inQueue = false,
		}
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = getQueuePosition(modeId, player)
	local waitingForArena = MatchStateService.isBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		playersInQueue = queue and #queue.players or 0,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		waitingForArena = waitingForArena,
		fillDeadline = queue and queue.fillDeadline,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueMode(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue.players do
		sendQueueUpdate(player)
	end
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		removeFromQueueList(queue, player)
		if #queue.players < MatchModes.get(modeId).minPlayers then
			queue.fillDeadline = nil
		end
	end

	playerQueue[player] = nil
	sendQueueUpdate(player)
	broadcastQueueMode(modeId)
end

local function popReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = math.min(#queue.players, mode.maxPlayers)
	local ready = {}

	for i = 1, count do
		table.insert(ready, queue.players[i])
	end

	for i = 1, count do
		table.remove(queue.players, 1)
	end

	queue.fillDeadline = nil
	return ready
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue.players < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue.players < mode.maxPlayers then
			if not queue.fillDeadline then
				queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
				broadcastQueueMode(modeId)
				return
			end
			if os.clock() < queue.fillDeadline then
				return
			end
		end
	end

	if MatchStateService.isBusy() then
		broadcastQueueMode(modeId)
		return
	end

	local readyPlayers = popReadyPlayers(modeId)
	if #readyPlayers < mode.minPlayers then
		return
	end

	for _, player in readyPlayers do
		playerQueue[player] = nil
		sendQueueUpdate(player)
	end

	broadcastQueueMode(modeId)

	if handlers.onMatchReady then
		handlers.onMatchReady(readyPlayers, modeId)
	end

	Bindables.MatchReady:Fire(readyPlayers, modeId)
end

local function processQueues()
	MatchModes.each(function(mode)
		tryStartMatch(mode.id)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] then
		leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= MatchModes.get(modeId).maxPlayers then
		sendQueueUpdate(player)
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueMode(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(newHandlers)
	if started then
		return
	end
	started = true
	handlers = newHandlers or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			processQueues()
		end
	end)
end

return MatchmakingService
