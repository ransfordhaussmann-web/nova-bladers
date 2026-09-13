local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local callbacks = {}
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingStart = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	if pendingStart and pendingStart.modeId == modeId then
		local stillQueued = {}
		for _, p in pendingStart.players do
			if playerQueue[p] == modeId then
				table.insert(stillQueued, p)
			end
		end
		if #stillQueued < (MatchModes.get(modeId) or {}).minPlayers then
			pendingStart = nil
		else
			pendingStart.players = stillQueued
		end
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local status = "waiting"

	if pendingStart and pendingStart.modeId == modeId then
		status = "pending"
	elseif mode and count >= mode.minPlayers and not GameMatchState.isArenaBusy() then
		if mode.fillTimeout > 0 and count < mode.maxPlayers then
			status = "filling"
		else
			status = "starting"
		end
	elseif mode and count >= mode.minPlayers and GameMatchState.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		players = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		inQueue = player ~= nil,
		statusLabel = status == "pending"
			and MatchmakingConfig.PENDING_LABEL
			or status == "starting"
			and MatchmakingConfig.STARTING_LABEL
			or MatchmakingConfig.WAITING_LABEL,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return false
	end
	if mode.fillTimeout > 0 and #queue < mode.maxPlayers and fillTimers[modeId] then
		return false
	end
	return true
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}
	for i = 1, count do
		table.insert(players, queue[i])
	end

	for _, player in players do
		removeFromQueue(player)
	end

	return players
end

local function startMatch(modeId)
	if not canStartMatch(modeId) or GameMatchState.isArenaBusy() then
		if canStartMatch(modeId) then
			local queue = getQueue(modeId)
			pendingStart = {
				modeId = modeId,
				players = table.clone(queue),
			}
			broadcastQueue(modeId)
		end
		return
	end

	local players = takePlayers(modeId)
	if #players == 0 then
		return
	end

	pendingStart = nil
	GameMatchState.setArenaBusy(true)

	for _, player in players do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		startMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode then
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout > 0 and #queue < mode.maxPlayers then
			scheduleFillTimer(modeId)
		else
			startMatch(modeId)
		end
	elseif fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	broadcastQueue(modeId)
end

local function joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if callbacks.getPhase and callbacks.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= MatchModes.get(modeId).maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	evaluateQueue(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	if modeId then
		broadcastQueue(modeId)
	end
end

local function onArenaFree()
	GameMatchState.setArenaBusy(false)

	if pendingStart then
		local modeId = pendingStart.modeId
		local mode = MatchModes.get(modeId)
		local queue = getQueue(modeId)
		if mode and #queue >= mode.minPlayers then
			startMatch(modeId)
			return
		end
		pendingStart = nil
	end

	for modeId in queues do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.start(opts)
	callbacks = opts or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = callbacks.getRecommendedMode and callbacks.getRecommendedMode() or "training"
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

function MatchmakingService.joinRecommended(player)
	local modeId = callbacks.getRecommendedMode and callbacks.getRecommendedMode() or "training"
	joinQueue(player, modeId)
end

function MatchmakingService.joinMode(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.getQueueSnapshot(modeId)
	return buildQueuePayload(modeId)
end

return MatchmakingService
