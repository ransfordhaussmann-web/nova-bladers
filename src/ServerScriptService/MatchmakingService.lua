--[[
	MatchmakingService — per-mode queues with arena-busy pending state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local arenaBusy = false
local fillTimerTokens = {}
local callbacks = {}

local function countQueue(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
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

	playerMode[player] = nil

	if modeId == "ffa" and countQueue("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		fillTimerTokens.ffa = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queueSize = countQueue(modeId)
	local status = arenaBusy and "pending" or "waiting"
	local statusText

	if arenaBusy then
		statusText = "Arena belegt — Warte auf freies Match..."
	elseif queueSize < mode.minPlayers then
		statusText = string.format("Warte auf Spieler (%d/%d)...", queueSize, mode.minPlayers)
	elseif modeId == "ffa" and queueSize < mode.maxPlayers then
		statusText = string.format("Spieler gefunden (%d/%d) — Füllt sich...", queueSize, mode.maxPlayers)
	else
		statusText = "Match startet gleich..."
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		playersInQueue = queueSize,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = statusText,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdates()
	if not callbacks.onQueueUpdate then
		return
	end

	for player, modeId in playerMode do
		if player.Parent then
			callbacks.onQueueUpdate(player, buildQueuePayload(player, modeId))
		end
	end
end

local function clearQueueEntry(player)
	removeFromQueue(player)
	if callbacks.onQueueLeft then
		callbacks.onQueueLeft(player)
	end
end

local function takePlayersFromQueue(modeId, amount)
	local taken = {}
	local queue = queues[modeId]

	for _ = 1, amount do
		local nextPlayer = queue[1]
		if not nextPlayer then
			break
		end
		table.remove(queue, 1)
		playerMode[nextPlayer] = nil
		table.insert(taken, nextPlayer)
	end

	if modeId == "ffa" then
		fillTimerTokens.ffa = nil
	end

	return taken
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.fillTimeout <= 0 or fillTimerTokens[modeId] then
		return
	end

	fillTimerTokens[modeId] = {}
	local token = fillTimerTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTimerTokens[modeId] ~= token then
			return
		end
		fillTimerTokens[modeId] = nil
		MatchmakingService.tryStartMatch(modeId, true)
	end)
end

function MatchmakingService.init(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastQueueUpdates()
	if not busy then
		MatchmakingService.processQueues()
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end

	if arenaBusy and playerMode[player] == modeId then
		broadcastQueueUpdates()
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	if modeId == "ffa" and countQueue(modeId) >= mode.minPlayers and countQueue(modeId) < mode.maxPlayers then
		startFillTimer(modeId)
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildQueuePayload(player, modeId))
	end

	MatchmakingService.processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end

	clearQueueEntry(player)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.removePlayer(player)
	if playerMode[player] then
		clearQueueEntry(player)
		broadcastQueueUpdates()
	end
end

function MatchmakingService.processQueues()
	if arenaBusy then
		return
	end

	for _, modeId in MatchmakingConfig.MODE_ORDER do
		local mode = MatchmakingConfig.getMode(modeId)
		if countQueue(modeId) >= mode.minPlayers then
			if MatchmakingService.tryStartMatch(modeId, false) then
				return
			end
		end
	end
end

function MatchmakingService.tryStartMatch(modeId, forceStart)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or arenaBusy then
		return false
	end

	local queueSize = countQueue(modeId)
	if queueSize < mode.minPlayers then
		return false
	end

	if modeId == "ffa" and queueSize < mode.maxPlayers and not forceStart then
		if not fillTimerTokens.ffa then
			startFillTimer(modeId)
		end
		broadcastQueueUpdates()
		return false
	end

	local playerCount = math.min(queueSize, mode.maxPlayers)
	local matchedPlayers = takePlayersFromQueue(modeId, playerCount)

	if #matchedPlayers < mode.minPlayers then
		for _, matchedPlayer in matchedPlayers do
			table.insert(queues[modeId], matchedPlayer)
			playerMode[matchedPlayer] = modeId
		end
		return false
	end

	arenaBusy = true
	broadcastQueueUpdates()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(matchedPlayers, modeId)
	end

	return true
end

return MatchmakingService
