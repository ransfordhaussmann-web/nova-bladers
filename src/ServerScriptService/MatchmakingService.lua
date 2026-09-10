local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local onQueueUpdate = nil
local onMatchReady = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countQueue(modeId)
	local list = queues[modeId]
	local count = 0
	for player, _ in list do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getQueuedPlayers(modeId)
	local list = {}
	for player, _ in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removeFromAllQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	queues[modeId][player] = nil
	playerQueue[player] = nil
	if fillTimers[modeId] and countQueue(modeId) < MatchmakingConfig.MODES[modeId].minPlayers then
		fillTimers[modeId] = nil
	end
end

local function buildUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local queued = countQueue(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode.fillTimeout > 0 and queued >= mode.minPlayers then
		status = "filling"
	end

	local fillTimeLeft = nil
	local timerStart = fillTimers[modeId]
	if timerStart and mode.fillTimeout > 0 then
		fillTimeLeft = math.max(0, math.ceil(mode.fillTimeout - (os.clock() - timerStart)))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = queued,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
	}
end

local function notifyPlayer(player)
	if onQueueUpdate and player.Parent then
		onQueueUpdate(player, buildUpdate(player))
	end
end

local function notifyAllQueued()
	for player, _ in playerQueue do
		notifyPlayer(player)
	end
end

function MatchmakingService.setCallbacks(callbacks)
	onQueueUpdate = callbacks.onQueueUpdate
	onMatchReady = callbacks.onMatchReady
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		notifyPlayer(player)
		return true
	end

	removeFromAllQueues(player)
	queues[modeId][player] = true
	playerQueue[player] = modeId
	notifyPlayer(player)
	notifyAllQueued()
	MatchmakingService.tryStartMatch()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		notifyPlayer(player)
		return false
	end
	removeFromAllQueues(player)
	notifyPlayer(player)
	notifyAllQueued()
	return true
end

function MatchmakingService.clearPlayers(players)
	for _, player in players do
		removeFromAllQueues(player)
		notifyPlayer(player)
	end
	notifyAllQueued()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
	notifyAllQueued()
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	local queued = getQueuedPlayers(modeId)
	local count = #queued

	if count < mode.minPlayers then
		return nil
	end

	if mode.fillTimeout > 0 then
		if count >= mode.maxPlayers then
			return queued
		end
		local timerStart = fillTimers[modeId]
		if not timerStart then
			fillTimers[modeId] = os.clock()
			notifyAllQueued()
			return nil
		end
		if os.clock() - timerStart < mode.fillTimeout then
			return nil
		end
		return queued
	end

	return queued
end

function MatchmakingService.tryStartMatch()
	if MatchStateService.isBusy() then
		notifyAllQueued()
		return
	end

	for _, modeId in { "ffa", "pvp", "training" } do
		local players = canStartMode(modeId)
		if players and #players > 0 then
			local mode = getMode(modeId)
			local matchPlayers = {}
			for i = 1, math.min(#players, mode.maxPlayers) do
				table.insert(matchPlayers, players[i])
			end

			fillTimers[modeId] = nil
			MatchmakingService.clearPlayers(matchPlayers)
			MatchStateService.setBusy(true)

			if onMatchReady then
				onMatchReady({
					mode = modeId,
					players = matchPlayers,
				})
			end
			return
		end
	end
end

function MatchmakingService.onArenaFreed()
	notifyAllQueued()
	MatchmakingService.tryStartMatch()
end

function MatchmakingService.tick()
	for modeId, mode in MatchmakingConfig.MODES do
		if mode.fillTimeout > 0 and fillTimers[modeId] and countQueue(modeId) >= mode.minPlayers then
			local elapsed = os.clock() - fillTimers[modeId]
			if elapsed >= mode.fillTimeout then
				MatchmakingService.tryStartMatch()
			else
				notifyAllQueued()
			end
		end
	end
end

return MatchmakingService
