--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local arenaBusy = false
local pendingReady = nil
local onReadyCallback = nil
local onUpdateCallback = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValid(players)
	local valid = {}
	for _, player in players do
		if player.Parent then
			table.insert(valid, player)
		end
	end
	return valid
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local players = countValid(queues[modeId])
	queues[modeId] = players

	local status = "waiting"
	if arenaBusy then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		fillRemaining = fillTimers[modeId],
		status = status,
	}
end

local function broadcastUpdate()
	if not onUpdateCallback then
		return
	end

	local seen = {}
	for modeId, players in queues do
		for _, player in players do
			if player.Parent and not seen[player] then
				seen[player] = true
				local payload = buildQueuePayload(playerQueue[player])
				onUpdateCallback(player, payload)
			end
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	local players = countValid(queues[modeId])
	if #players < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = mode.fillTimeout
	task.spawn(function()
		while fillTimers[modeId] and fillTimers[modeId] > 0 do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			if not fillTimers[modeId] then
				return
			end
			fillTimers[modeId] -= MatchmakingConfig.QUEUE_UPDATE_INTERVAL
			broadcastUpdate()
		end

		if fillTimers[modeId] then
			clearFillTimer(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastUpdate()
	if not busy then
		MatchmakingService.processPending()
	end
end

function MatchmakingService.setOnReady(callback)
	onReadyCallback = callback
end

function MatchmakingService.setOnUpdate(callback)
	onUpdateCallback = callback
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	playerQueue[player] = nil
	local players = queues[modeId]
	for i, queued in players do
		if queued == player then
			table.remove(players, i)
			break
		end
	end

	local mode = getMode(modeId)
	if countValid(players) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if onUpdateCallback and player.Parent then
		onUpdateCallback(player, nil)
	end
	broadcastUpdate()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastUpdate()
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	local players = countValid(queues[modeId])
	queues[modeId] = players

	if #players < mode.minPlayers then
		return false
	end

	if #players >= mode.maxPlayers then
		clearFillTimer(modeId)
		return MatchmakingService.dispatchMatch(modeId, players)
	end

	if #players >= mode.minPlayers and mode.fillTimeout > 0 then
		startFillTimer(modeId)
		return false
	end

	if #players >= mode.minPlayers then
		return MatchmakingService.dispatchMatch(modeId, players)
	end

	return false
end

function MatchmakingService.dispatchMatch(modeId, players)
	local mode = getMode(modeId)
	local roster = {}
	for i = 1, math.min(#players, mode.maxPlayers) do
		table.insert(roster, players[i])
	end

	if #roster < mode.minPlayers then
		return false
	end

	for _, player in roster do
		MatchmakingService.leaveQueue(player)
	end

	local payload = {
		mode = modeId,
		players = roster,
	}

	if arenaBusy then
		pendingReady = payload
		broadcastUpdate()
		return true
	end

	if onReadyCallback then
		onReadyCallback(payload)
	end
	return true
end

function MatchmakingService.processPending()
	if arenaBusy or not pendingReady then
		return
	end

	local payload = pendingReady
	pendingReady = nil

	if onReadyCallback then
		onReadyCallback(payload)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
