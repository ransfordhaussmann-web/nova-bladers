local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTimers = {}
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getQueueList(modeId)
	local list = {}
	for player in playerQueue do
		if playerQueue[player] == modeId and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local queue = getQueueList(modeId)
	local position = 1
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local modeConfig = MatchState.getModeConfig(modeId)
	local status = arenaBusy and "pending" or "waiting"

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = modeConfig.label,
		position = position,
		queued = #queue,
		required = modeConfig.minPlayers,
		maxPlayers = modeConfig.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueueList(modeId)
	for _, player in queue do
		if callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, buildUpdatePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local modeConfig = MatchState.getModeConfig(modeId)
	if not modeConfig.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(modeConfig.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function popPlayers(modeId, count)
	local queue = getQueueList(modeId)
	local picked = {}
	for i = 1, math.min(count, #queue) do
		table.insert(picked, queue[i])
	end

	for _, player in picked do
		playerQueue[player] = nil
	end

	return picked
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastAllQueues()
	if not busy then
		for modeId in MatchmakingConfig.MODES do
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil

	local remaining = #getQueueList(modeId)
	local modeConfig = MatchState.getModeConfig(modeId)
	if modeConfig and modeConfig.fillTimeout and remaining < modeConfig.minPlayers then
		clearFillTimer(modeId)
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchState.isValidMode(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		if callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, buildUpdatePayload(player))
		end
		return true
	end

	MatchmakingService.leaveQueue(player)
	playerQueue[player] = modeId

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildUpdatePayload(player))
	end
	broadcastQueueUpdate(modeId)

	local modeConfig = MatchState.getModeConfig(modeId)
	local queueSize = #getQueueList(modeId)

	if modeId == "ffa" and queueSize >= modeConfig.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.joinAutoQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchState.getAutoModeId(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local modeConfig = MatchState.getModeConfig(modeId)
	local queue = getQueueList(modeId)
	local queueSize = #queue

	if queueSize < modeConfig.minPlayers then
		return
	end

	local startCount = queueSize
	if queueSize > modeConfig.maxPlayers then
		startCount = modeConfig.maxPlayers
	end

	if modeId == "ffa" and queueSize < modeConfig.maxPlayers and fillTimers[modeId] then
		return
	end

	local players = popPlayers(modeId, startCount)
	clearFillTimer(modeId)

	if #players < modeConfig.minPlayers then
		for _, player in players do
			playerQueue[player] = modeId
		end
		broadcastQueueUpdate(modeId)
		return
	end

	arenaBusy = true
	broadcastAllQueues()

	if callbacks.onMatchReady then
		local accepted = callbacks.onMatchReady({
			mode = modeId,
			players = players,
		})
		if accepted == false then
			arenaBusy = false
			for _, player in players do
				playerQueue[player] = modeId
			end
			broadcastQueueUpdate(modeId)
		end
	end
end

function MatchmakingService.register(newCallbacks)
	for key, fn in newCallbacks do
		callbacks[key] = fn
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
