--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingModes = {}
local remotes = nil
local matchReadyBindable = nil
local running = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if pendingModes[modeId] then
		status = "pending"
	elseif mode.fillTimeout > 0 and getQueueSize(modeId) >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = getQueueSize(modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	fillTimers[modeId] = true
	broadcastQueueUpdate(modeId)

	task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStart(modeId)
	end)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if getQueueSize(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
		pendingModes[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end
	return taken
end

function MatchmakingService.tryStart(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 and size < mode.maxPlayers and fillTimers[modeId] then
		return
	end

	if MatchStateService.isBusy() then
		pendingModes[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	pendingModes[modeId] = nil
	clearFillTimer(modeId)

	local playerCount = math.min(size, mode.maxPlayers)
	local players = takePlayers(modeId, playerCount)
	if #players == 0 then
		return
	end

	broadcastQueueUpdate(modeId)
	matchReadyBindable:Fire(players, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if getQueueSize(modeId) >= mode.minPlayers then
		if mode.fillTimeout > 0 and getQueueSize(modeId) < mode.maxPlayers then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStart(modeId)
		end
	else
		broadcastQueueUpdate(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(remoteFolder, matchReadyEvent)
	remotes = remoteFolder
	matchReadyBindable = matchReadyEvent
	initQueues()
	running = true

	MatchStateService.onArenaFree(function()
		for modeId in queues do
			if getQueueSize(modeId) > 0 then
				MatchmakingService.tryStart(modeId)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while running do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId, queue in queues do
				local mode = MatchModes.get(modeId)
				if mode and #queue >= mode.minPlayers and not fillTimers[modeId] then
					MatchmakingService.tryStart(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
