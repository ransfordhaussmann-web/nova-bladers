local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local callbacks = {}

local function getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			pendingArena = false,
		}
	end
	return queues[modeId]
end

local function getQueuePosition(modeId, player)
	local queue = ensureQueue(modeId)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or count,
		position = getQueuePosition(modeId, player),
		pendingArena = queue.pendingArena,
	}
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	if #queue.players == 0 then
		queue.pendingArena = false
	end
end

local function takeMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue.players, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end
	end

	queue.pendingArena = false
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	return matchPlayers
end

local function launchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	GameMatchState.setBusy(true)

	for _, player in matchPlayers do
		if callbacks.onMatchReady then
			callbacks.onMatchReady(player)
		end
	end

	MatchReady:Fire(modeId, matchPlayers)
	broadcastQueueUpdates()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue.players < mode.minPlayers then
		queue.pendingArena = false
		return
	end

	if GameMatchState.isBusy() then
		queue.pendingArena = true
		broadcastQueueUpdates()
		return
	end

	local timeout = mode.fillTimeout
	if modeId == "ffa" then
		timeout = MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	if timeout > 0 and #queue.players < mode.maxPlayers then
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		local token = fillTokens[modeId]

		task.delay(timeout, function()
			if token ~= fillTokens[modeId] then
				return
			end
			if #queue.players < mode.minPlayers then
				return
			end
			if GameMatchState.isBusy() then
				queue.pendingArena = true
				broadcastQueueUpdates()
				return
			end
			launchMatch(modeId, takeMatchPlayers(modeId))
		end)
		return
	end

	launchMatch(modeId, takeMatchPlayers(modeId))
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = getActiveModeId()
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		return
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	broadcastQueueUpdates()
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
end

local function retryPendingQueues()
	for modeId, queue in queues do
		if #queue.players >= (MatchModes.get(modeId) and MatchModes.get(modeId).minPlayers or 999) then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.start(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	for _, mode in MatchModes.all() do
		ensureQueue(mode.id)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		task.defer(broadcastQueueUpdates)
	end)

	GameMatchState.onArenaFree(function()
		retryPendingQueues()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

function MatchmakingService.getActiveModeId()
	return getActiveModeId()
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
