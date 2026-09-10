--[[
	MatchmakingService — per-mode queues with fill timeout and arena-busy pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local isArenaBusy = function()
	return false
end
local onMatchReady
local remotes

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function playerInList(list, player)
	for i, p in list do
		if p == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, player)
	local mode = getModeConfig(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local count = #queue
	local needed = math.max(0, mode.minPlayers - count)
	local busy = isArenaBusy()
	local status = "waiting"
	if busy then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	local timeLeft
	if mode.fillTimeout and fillTimers[modeId] then
		timeLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = needed,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		timeLeft = timeLeft,
		inQueue = playerInList(queue, player) ~= nil,
	}
end

function MatchmakingService.broadcastQueueUpdate(modeId)
	if not remotes or not remotes.QueueUpdate then
		return
	end

	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	local token = { cancelled = false, endsAt = os.clock() + mode.fillTimeout }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

function MatchmakingService.init(remoteFolder, matchReadyCallback)
	remotes = remoteFolder
	onMatchReady = matchReadyCallback
end

function MatchmakingService.setArenaBusyCheck(fn)
	isArenaBusy = fn
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	local queue = getQueue(modeId)
	local idx = playerInList(queue, player)
	if idx then
		table.remove(queue, idx)
	end
	playerQueue[player] = nil

	if #queue < getModeConfig(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout then
		startFillTimer(modeId)
	elseif #queue >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end

	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	if isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local matchPlayers = {}
	local takeCount = math.min(#queue, mode.maxPlayers)
	for i = 1, takeCount do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		MatchmakingService.leaveQueue(player)
	end

	clearFillTimer(modeId)

	if onMatchReady then
		onMatchReady(modeId, matchPlayers)
	end

	return true
end

function MatchmakingService.onArenaFreed()
	for modeId in MatchmakingConfig.MODES do
		local queue = getQueue(modeId)
		if #queue > 0 then
			broadcastQueueUpdate(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getQueuePayload(player, modeId)
	if modeId then
		return buildQueuePayload(modeId, player)
	end

	local queuedMode = playerQueue[player]
	if queuedMode then
		return buildQueuePayload(queuedMode, player)
	end
	return nil
end

return MatchmakingService
