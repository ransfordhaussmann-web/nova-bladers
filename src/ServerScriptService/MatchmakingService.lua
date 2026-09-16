--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local queues = {}
local playerQueue = {}
local fillTokens = {}
local started = false
local dispatching = false
local onMatchReadyCallback

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
		fillTokens[mode.id] = 0
	end
end

local function buildQueuePayload(modeId, player)
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
	if MatchStateService.isArenaBusy() and position > 0 and #queue >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueue(mode.id)
	end
end

local function removeFromQueue(player, silent)
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

	if not silent then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		broadcastQueue(modeId)
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return false
	end
	return #queue >= mode.minPlayers
end

local function dispatchMatch(modeId)
	if not canStartMode(modeId) then
		return false
	end

	if dispatching or MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	dispatching = true

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}
	for i = 1, count do
		table.insert(players, queue[i])
	end

	if #players == 0 then
		dispatching = false
		return false
	end

	for _, player in players do
		removeFromQueue(player, true)
	end
	broadcastQueue(modeId)
	fillTokens[modeId] += 1
	MatchStateService.setArenaBusy(true)
	dispatching = false

	Bindables.MatchReady:Fire(players, mode.id)

	if onMatchReadyCallback then
		onMatchReadyCallback(players, mode.id)
	end

	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if canStartMode(modeId) then
			dispatchMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueue(modeId)

	if #queue >= mode.minPlayers and mode.fillTimeout <= 0 then
		dispatchMatch(modeId)
	elseif #queue == mode.minPlayers and mode.fillTimeout > 0 then
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onArenaFree()
	broadcastAllQueues()
	for _, mode in MatchModes.all() do
		if canStartMode(mode.id) and dispatchMatch(mode.id) then
			break
		end
	end
end

function MatchmakingService.onMatchReady(callback)
	onMatchReadyCallback = callback
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			if MatchStateService.isArenaBusy() then
				for _, mode in MatchModes.all() do
					local queue = queues[mode.id]
					if queue and #queue >= mode.minPlayers then
						broadcastQueue(mode.id)
					end
				end
			end
		end
	end)
end

initQueues()

return MatchmakingService
