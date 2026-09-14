local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local running = false

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
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.getMode(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		position = position,
		pending = GameMatchState.isBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function launchMatch(modeId, roster)
	for _, player in roster do
		removeFromQueue(player)
	end
	broadcastAllQueues()
	MatchReady:Fire(modeId, roster)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.getMode(modeId)
	if not mode then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local roster = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(roster, queue[i])
	end

	launchMatch(modeId, roster)
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = os.clock()
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		local mode = MatchModes.getMode(modeId)
		local queue = getQueue(modeId)
		if not mode or #queue < mode.minPlayers then
			return
		end
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	if mode.waitForFill and #queue >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	if not mode.waitForFill or #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	else
		broadcastQueue(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.start()
	if running then
		return
	end
	running = true

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while running do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			if GameMatchState.isBusy() then
				broadcastAllQueues()
			else
				for modeId in queues do
					tryStartMatch(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
