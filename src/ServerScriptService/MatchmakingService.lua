--[[
	MatchmakingService — per-mode queues with fill timeout for FFA.
	Fires MatchReady when enough players are waiting and the arena is free.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local initialized = false
local queues = {}
local playerQueue = {}
local arenaBusy = false
local pendingMatch = nil
local fillTimers = {}

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function getPlayerPosition(player, modeId)
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = getPlayerPosition(player, modeId),
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		status = status or "waiting",
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			local status = "waiting"
			if pendingMatch and pendingMatch.modeId == modeId then
				local inPending = false
				for _, p in pendingMatch.players do
					if p == player then
						inPending = true
						break
					end
				end
				if inPending then
					status = "pending"
				end
			end
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode.fillTimeout then
		return
	end
	clearFillTimer(modeId)
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if getQueueSize(modeId) >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil

	if getQueueSize(modeId) < MatchmakingConfig.getMode(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processPending()
	end
end

function MatchmakingService.processPending()
	if arenaBusy or not pendingMatch then
		return
	end

	local modeId = pendingMatch.modeId
	local players = pendingMatch.players
	pendingMatch = nil

	for _, player in players do
		removeFromQueue(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	local players = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(players, queue[i])
	end

	if arenaBusy then
		pendingMatch = { modeId = modeId, players = players }
		broadcastQueueUpdate(modeId)
		return
	end

	clearFillTimer(modeId)
	for _, player in players do
		removeFromQueue(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return false, "already_queued"
		end
		removeFromQueue(player)
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]

	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(player, modeId, "waiting")
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueueUpdate(modeId)

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout then
		if not fillTimers[modeId] then
			startFillTimer(modeId)
		end
	elseif #queue >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

function MatchmakingService.init()
	if initialized then
		return MatchmakingService
	end
	initialized = true

	initQueues()

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
		removeFromQueue(player)
		if pendingMatch then
			for i, p in pendingMatch.players do
				if p == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players < MatchmakingConfig.getMode(pendingMatch.modeId).minPlayers then
				pendingMatch = nil
			end
		end
	end)

	return MatchmakingService
end

return MatchmakingService
