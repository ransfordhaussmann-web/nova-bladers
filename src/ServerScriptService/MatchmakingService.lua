local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady, ArenaFree
local QueueJoin, QueueLeave, QueueUpdate

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingMatches = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	return #queue
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId] or {}
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if GameMatchState.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = position,
		queueSize = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeout = mode and mode.fillTimeout or 0,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastQueueUpdate(modeId)
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
		HubService.leaveHubForArena(player)
	end

	pendingMatches[modeId] = nil
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	if GameMatchState.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue < mode.minPlayers then
		return false
	end

	local playerList = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player and player.Parent then
			table.insert(playerList, player)
		end
	end

	if #playerList < mode.minPlayers then
		return false
	end

	startMatch(modeId, playerList)
	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = queues[modeId]
		if not queue or #queue < mode.minPlayers then
			return
		end

		if GameMatchState.isArenaBusy() then
			pendingMatches[modeId] = true
			broadcastQueueUpdate(modeId)
			return
		end

		tryStartMatch(modeId)
	end)
end

local function joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = queues[modeId]
	if not queue then
		return
	end

	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if #queue == 1 and mode.fillTimeout > 0 then
		scheduleFillTimeout(modeId)
	end

	if #queue >= mode.minPlayers and mode.fillTimeout <= 0 then
		if GameMatchState.isArenaBusy() then
			pendingMatches[modeId] = true
			broadcastQueueUpdate(modeId)
		else
			tryStartMatch(modeId)
		end
	elseif #queue >= mode.maxPlayers then
		if GameMatchState.isArenaBusy() then
			pendingMatches[modeId] = true
			broadcastQueueUpdate(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

local function processPendingMatches()
	for modeId, pending in pendingMatches do
		if pending and tryStartMatch(modeId) then
			pendingMatches[modeId] = nil
		end
	end
end

local function onArenaFree()
	processPendingMatches()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not started then
		return
	end
	if typeof(modeId) ~= "string" then
		return
	end
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not started then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree
	QueueJoin = Remotes.QueueJoin
	QueueLeave = Remotes.QueueLeave
	QueueUpdate = Remotes.QueueUpdate

	initQueues()

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if not GameMatchState.isArenaBusy() then
				processPendingMatches()
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
