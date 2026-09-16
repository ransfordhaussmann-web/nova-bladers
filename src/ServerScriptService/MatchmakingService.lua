local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local callbacks = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			pending = false,
			status = "waiting",
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function getFillTimeLeft(queue)
	if not queue.fillDeadline then
		return nil
	end
	return math.max(0, math.ceil(queue.fillDeadline - os.clock()))
end

local function buildQueuePayload(modeId, queue)
	local mode = MatchModes.get(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = queue.pending,
		status = queue.status,
		fillTimeLeft = getFillTimeLeft(queue),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local payload = buildQueuePayload(modeId, queue)
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local queue = queues[modeId]
	if queue then
		queue.fillDeadline = nil
	end
end

local function removePlayerFromQueue(player, silent)
	local info = playerQueue[player]
	if not info then
		return
	end

	local modeId = info.modeId
	local queue = queues[modeId]
	if queue then
		for index, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, index)
				break
			end
		end

		if #queue.players < MatchModes.get(modeId).minPlayers then
			clearFillTimer(modeId)
			queue.status = "waiting"
			queue.pending = false
		end
	end

	playerQueue[player] = nil

	if not silent then
		broadcastQueueUpdate(modeId)
	end
end

local function buildMatchRoster(modeId)
	local queue = ensureQueue(modeId)
	local mode = MatchModes.get(modeId)
	local matchPlayers = {}

	for index = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[index])
	end

	return matchPlayers
end

local function tryStartMatch(modeId)
	local queue = ensureQueue(modeId)
	local mode = MatchModes.get(modeId)

	if #queue.players < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		queue.pending = true
		queue.status = "pending"
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = buildMatchRoster(modeId)
	if #matchPlayers == 0 then
		return
	end

	if callbacks.onMatchStarting then
		callbacks.onMatchStarting(matchPlayers, modeId)
	end

	MatchReady:Fire(matchPlayers, modeId)
end

function MatchmakingService.confirmMatchStarted(playerList)
	for _, player in playerList do
		removePlayerFromQueue(player, true)
	end

	for modeId, queue in queues do
		if #queue.players == 0 then
			queue.pending = false
			queue.status = "waiting"
			clearFillTimer(modeId)
		end
		broadcastQueueUpdate(modeId)
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	local queue = ensureQueue(modeId)
	if queue.fillDeadline then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	queue.fillDeadline = os.clock() + mode.fillTimeout
	queue.status = "filling"
	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local currentQueue = queues[modeId]
		if not currentQueue or #currentQueue.players < mode.minPlayers then
			return
		end

		tryStartMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local queue = ensureQueue(modeId)
	local mode = MatchModes.get(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		queue.status = "waiting"
		queue.pending = false
		clearFillTimer(modeId)
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	startFillTimer(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	if MatchStateService.isArenaBusy() and playerQueue[player] then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	removePlayerFromQueue(player, false)
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaBusy(false)

	for modeId in MatchModes.list do
		local queue = queues[modeId]
		if queue and #queue.players >= MatchModes.get(modeId).minPlayers then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	local info = playerQueue[player]
	return info and info.modeId
end

function MatchmakingService.start(options)
	callbacks = options or {}

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.resolveDefault(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId, queue in queues do
				if queue.fillDeadline and queue.status == "filling" then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
